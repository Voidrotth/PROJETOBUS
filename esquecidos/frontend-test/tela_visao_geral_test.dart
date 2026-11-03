import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projetobus_frontend/tema/tema.dart';
import 'package:projetobus_frontend/visao_geral/tela_visao_geral.dart';

// fixtures/indicadores.json: resposta real de GET /api/indicadores (jul–set/2026, último dia 14/09)
void main() {
  final resposta = File('test/fixtures/indicadores.json').readAsBytesSync();
  MockClient cliente() => MockClient(
      (_) async => http.Response.bytes(resposta, 200, headers: {'content-type': 'application/json; charset=utf-8'}));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrir(WidgetTester tester, Size tamanho) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: criarTema(), home: const Scaffold(body: TelaVisaoGeral(tempoReal: false))));
      await tester.pumpAndSettle();
    }, cliente);
  }

  testWidgets('painel abre no último dia com dados e troca de período sozinha a cada minuto', (tester) async {
    await abrir(tester, const Size(1920, 1080));

    for (final titulo in [
      'Quilometragem',
      'Viagens',
      'Passageiros Pagantes',
      'Passageiros Não Pagantes',
      'Informações Financeiras',
    ]) {
      expect(find.text(titulo), findsOneWidget);
    }
    expect(find.text('Seg, 14/09/2026'), findsOneWidget);
    expect(find.text('dados até 14/09/2026'), findsOneWidget);
    expect(find.text('10.058 km'), findsOneWidget);
    // 07/09 (feriado, programação reduzida) não entra na comparação da segunda 14/09: vai para 31/08
    expect(find.text('-0,4% vs Seg, 31/08'), findsOneWidget);
    expect(find.textContaining('vs Seg, 07/09'), findsNothing);
    // Receita de catraca não vem nos relatórios: aparece como sem dado, nunca como zero
    expect(find.textContaining('receita de catraca sem dado'), findsOneWidget);
    expect(find.text('Crédito circulante sem alerta'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Future<void> umMinuto() async {
      for (var i = 0; i < segundosPorPeriodoPadrao; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    await umMinuto();
    expect(find.text('14/09 – 20/09/2026'), findsOneWidget);
    await umMinuto();
    expect(find.text('1ª quinzena · set/2026'), findsOneWidget);
    await umMinuto();
    expect(find.text('Setembro de 2026'), findsOneWidget);
    await umMinuto();
    expect(find.text('Seg, 14/09/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Layout de celular (390 px) sem overflow', (tester) async {
    await abrir(tester, const Size(390, 3000));
    expect(tester.takeException(), isNull);
    expect(find.text('Informações Financeiras'), findsOneWidget);
  });

  testWidgets('Layout de tablet (900 px) sem overflow', (tester) async {
    await abrir(tester, const Size(900, 3000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('− e + mudam o tempo de cada período (de 10 em 10 s) e ficam salvos', (tester) async {
    await abrir(tester, const Size(1920, 1080));
    expect(find.text('60s'), findsOneWidget);

    await tester.tap(find.byTooltip('Menos tempo'));
    await tester.pump();
    expect(find.text('50s'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getInt('segundos_por_periodo'), 50);

    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('14/09 – 20/09/2026'), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('Menos tempo'));
    }
    await tester.pump();
    expect(find.text('10s'), findsOneWidget); // não passa do mínimo
  });
}
