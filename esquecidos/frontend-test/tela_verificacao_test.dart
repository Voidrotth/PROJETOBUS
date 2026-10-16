import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetobus_frontend/telas/tela_verificacao.dart';

// fixtures/indicadores.json é a resposta real de GET /api/indicadores?tipos=util
// para os relatórios de jul–set/2026 (pasta dados/).
void main() {
  testWidgets('Verificação monta os módulos com os dados reais', (tester) async {
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final resposta = File('test/fixtures/indicadores.json').readAsBytesSync();

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TelaVerificacao())));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => http.Response.bytes(resposta, 200, headers: {'content-type': 'application/json; charset=utf-8'})));

    expect(find.text('Demanda diária de passageiros'), findsOneWidget);
    expect(find.text('Receita diária'), findsOneWidget);
    expect(find.text('Crédito circulante'), findsOneWidget);
    expect(find.text('Quilometragem'), findsOneWidget);
    // Só dias úteis vêm marcados por padrão
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Dias úteis')).selected, isTrue);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Feriados')).selected, isFalse);
    // Pico semanal e alerta saem dos dados
    expect(find.textContaining('Em 8 de 8 semanas completas'), findsOneWidget);
    expect(find.text('Sem alerta'), findsOneWidget);
    // Receita de catraca não vem nos relatórios: aparece como sem dado, nunca como zero
    expect(find.text('sem dado'), findsWidgets);
  });
}
