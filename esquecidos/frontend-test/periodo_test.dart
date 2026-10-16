import 'package:flutter_test/flutter_test.dart';
import 'package:projetobus_frontend/visao_geral/periodo.dart';

void main() {
  DateTime d(int ano, int mes, int dia) => DateTime.utc(ano, mes, dia);

  test('Semana vai de segunda a domingo, inclusive cruzando o mês', () {
    // 14/09/2026 é segunda
    final semana = Periodo.contendo(TipoPeriodo.semanal, d(2026, 9, 14));
    expect(semana.inicio, d(2026, 9, 14));
    expect(semana.fim, d(2026, 9, 20));

    final virada = Periodo.contendo(TipoPeriodo.semanal, d(2026, 10, 1)); // quinta
    expect(virada.inicio, d(2026, 9, 28));
    expect(virada.fim, d(2026, 10, 4));
    expect(virada.rotulo, '28/09 – 04/10/2026');

    final anoNovo = Periodo.contendo(TipoPeriodo.semanal, d(2027, 1, 1));
    expect(anoNovo.rotulo, '28/12/2026 – 03/01/2027');
  });

  test('Quinzenas: 1 a 15 e 16 ao fim do mês (fevereiro e mês de 31 dias)', () {
    final primeira = Periodo.contendo(TipoPeriodo.quinzenal, d(2026, 2, 15));
    expect((primeira.inicio, primeira.fim), (d(2026, 2, 1), d(2026, 2, 15)));

    final fevereiro = Periodo.contendo(TipoPeriodo.quinzenal, d(2026, 2, 16));
    expect((fevereiro.inicio, fevereiro.fim), (d(2026, 2, 16), d(2026, 2, 28)));
    expect(Periodo.contendo(TipoPeriodo.quinzenal, d(2028, 2, 20)).fim, d(2028, 2, 29));

    final agosto = Periodo.contendo(TipoPeriodo.quinzenal, d(2026, 8, 31));
    expect((agosto.inicio, agosto.fim, agosto.dias), (d(2026, 8, 16), d(2026, 8, 31), 16));
    expect(agosto.rotulo, '2ª quinzena · ago/2026');
    expect(agosto.proximo().rotulo, '1ª quinzena · set/2026');
    expect(agosto.anterior().rotulo, '1ª quinzena · ago/2026');
  });

  test('Mês, dia, anterior e próximo', () {
    final setembro = Periodo.contendo(TipoPeriodo.mensal, d(2026, 9, 14));
    expect((setembro.inicio, setembro.fim), (d(2026, 9, 1), d(2026, 9, 30)));
    expect(setembro.rotulo, 'Setembro de 2026');
    expect(setembro.anterior().rotulo, 'Agosto de 2026');
    expect(Periodo.contendo(TipoPeriodo.mensal, d(2026, 1, 10)).anterior().rotulo, 'Dezembro de 2025');

    final dia = Periodo.contendo(TipoPeriodo.diario, d(2026, 9, 14));
    expect(dia.rotulo, 'Seg, 14/09/2026');
    expect(dia.anterior().rotulo, 'Dom, 13/09/2026');
    // O dia é comparado com o mesmo dia da semana anterior
    expect(dia.comparacao().rotulo, 'Seg, 07/09/2026');
    expect(setembro.comparacao(), setembro.anterior());
  });

  test('contem e conversão de datas', () {
    final semana = Periodo.contendo(TipoPeriodo.semanal, dataDeIso('2026-09-10'));
    expect(semana.contem('2026-09-07'), isTrue);
    expect(semana.contem('2026-09-13'), isTrue);
    expect(semana.contem('2026-09-14'), isFalse);
    expect(semana.datas.map(isoDeData).first, '2026-09-07');
    expect(semana.datas, hasLength(7));
  });
}
