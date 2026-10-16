import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetobus_frontend/visao_geral/periodo.dart';
import 'package:projetobus_frontend/visao_geral/resumo_periodo.dart';

// fixtures/indicadores.json: resposta real de GET /api/indicadores?tipos=util (jul–set/2026)
void main() {
  final resposta = jsonDecode(File('test/fixtures/indicadores.json').readAsStringSync());
  final dias = prepararDias((resposta['dias'] as List).cast<Map<String, dynamic>>());

  ResumoPeriodo resumo(TipoPeriodo tipo, String data) => ResumoPeriodo.de(dias, Periodo.contendo(tipo, dataDeIso(data)));

  test('Soma os indicadores da semana', () {
    final semana = resumo(TipoPeriodo.semanal, '2026-09-10');
    expect(semana.dias, hasLength(5)); // o fixture só tem dias úteis
    expect(semana.kmTotal, closeTo(45776.2, 0.01));
    expect(semana.viagensRealizadas, 5825);
    expect(semana.pagantes, 46576);
    expect(semana.naoPagantes, 132415);
    expect(semana.vendas, closeTo(39860.01, 0.01));
  });

  test('Soma os indicadores do mês e calcula o cumprimento', () {
    final agosto = resumo(TipoPeriodo.mensal, '2026-08-20');
    expect(agosto.kmTotal, closeTo(211632.8, 0.01));
    expect(agosto.viagensRealizadas, 26839);
    expect(agosto.viagensProgramadas, 26880);
    expect(agosto.cumprimento, closeTo(26839 / 26880, 1e-9));
    // O fixture não traz o relatório de turnos
    expect(agosto.turnos, isNull);
  });

  test('Soma o cumprimento por turno quando o relatório de turnos existe', () {
    final comTurnos = [
      for (final (data, mp, mr) in [('2026-09-14', 500, 498), ('2026-09-15', 500, 500)])
        {
          'data': data,
          'manhaProgramadas': mp, 'manhaRealizadas': mr,
          'tardeProgramadas': 400, 'tardeRealizadas': 400,
          'noiteProgramadas': 380, 'noiteRealizadas': 370,
        }
    ];
    final turnos = ResumoPeriodo.de(comTurnos, Periodo.contendo(TipoPeriodo.semanal, dataDeIso('2026-09-14'))).turnos!;
    expect(turnos.map((t) => t.nome), ['Manhã', 'Tarde', 'Noite']);
    expect(turnos.first.programadas, 1000);
    expect(turnos.first.realizadas, 998);
    expect(turnos.last.cumprimento, closeTo(740 / 760, 1e-9));
  });

  test('Grupo sem dado fica nulo (nunca zero)', () {
    final semana = resumo(TipoPeriodo.semanal, '2026-09-10');
    expect(semana.receitaCatraca, isNull);
    // Sem receita de catraca, a receita é só a dos créditos vendidos
    expect(semana.receita, closeTo(39860.01, 0.01));

    // Passageiros só começam em 15/07
    final julho = resumo(TipoPeriodo.mensal, '2026-07-10');
    expect(julho.diasCom('pagantes'), 13);
    expect(julho.diasCom('kmTotal'), 23);
    final inicioJulho = resumo(TipoPeriodo.semanal, '2026-07-08');
    expect(inicioJulho.pagantes, isNull);
    expect(inicioJulho.percentualNaoPagantes, isNull);

    // Período fora dos dados
    final vazio = resumo(TipoPeriodo.mensal, '2026-01-10');
    expect(vazio.kmTotal, isNull);
    expect(vazio.turnos, isNull);
  });

  test('Variação usa a média diária contra o período anterior', () {
    final agosto = resumo(TipoPeriodo.mensal, '2026-08-20');
    final julho = resumo(TipoPeriodo.mensal, '2026-07-20');
    final esperado = (211632.8 / 21) / (211758.3 / 23) - 1;
    expect(agosto.variacao(julho, 'kmTotal'), closeTo(esperado, 1e-9));
    // Sem dado no anterior: sem comparação
    expect(julho.variacao(resumo(TipoPeriodo.mensal, '2026-06-10'), 'kmTotal'), isNull);
  });
}
