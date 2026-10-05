import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetobus_frontend/tema/tema.dart';
import 'package:projetobus_frontend/visao_geral/tela_visao_geral.dart';

// fixtures/indicadores.json: resposta real de GET /api/indicadores (jul–set/2026, último dia 14/09)
void main() {
  final resposta = File('test/fixtures/indicadores.json').readAsBytesSync();
  MockClient cliente() => MockClient(
      (_) async => http.Response.bytes(resposta, 200, headers: {'content-type': 'application/json; charset=utf-8'}));

  Future<void> abrir(WidgetTester tester, Size tamanho) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: criarTema(), home: const Scaffold(body: TelaVisaoGeral(tempoReal: false))));
      await tester.pumpAndSettle();
    }, cliente);
  }

  testWidgets('Visão Geral abre no último dia com dados e troca de período', (tester) async {
    await abrir(tester, const Size(1440, 2000));

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
    // Receita de catraca não vem nos relatórios: aparece como sem dado, nunca como zero
    expect(find.textContaining('receita de catraca sem dado'), findsOneWidget);
    expect(find.text('Crédito circulante sem alerta'), findsOneWidget);

    await tester.tap(find.text('Mensal'));
    await tester.pumpAndSettle();
    expect(find.text('Setembro de 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Período anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Agosto de 2026'), findsOneWidget);
    expect(find.text('211.633 km'), findsOneWidget);

    // Agosto -> quinzenal fica na 2ª quinzena de agosto
    await tester.tap(find.text('Quinzenal'));
    await tester.pumpAndSettle();
    expect(find.text('2ª quinzena · ago/2026'), findsOneWidget);

    await tester.tap(find.text('Semanal'));
    await tester.pumpAndSettle();
    expect(find.text('31/08 – 06/09/2026'), findsOneWidget);
  });

  testWidgets('Não dá para avançar além do último dia com dados', (tester) async {
    await abrir(tester, const Size(1440, 2000));
    final avancar = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(avancar.onPressed, isNull);
  });

  testWidgets('Layout de celular (390 px) sem overflow', (tester) async {
    await abrir(tester, const Size(390, 3000));
    expect(tester.takeException(), isNull);
    expect(find.text('Informações Financeiras'), findsOneWidget);
    await tester.tap(find.text('Mensal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Layout de tablet (900 px) sem overflow', (tester) async {
    await abrir(tester, const Size(900, 3000));
    await tester.tap(find.text('Semanal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
