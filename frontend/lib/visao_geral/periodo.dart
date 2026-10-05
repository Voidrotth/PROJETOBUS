/// Recortes de tempo do painel. Datas sempre em UTC (só dia, sem hora) para não
/// sofrer com fuso ou horário de verão.
enum TipoPeriodo {
  diario('Diário', 'mesmo dia da semana anterior'),
  semanal('Semanal', 'semana anterior'),
  quinzenal('Quinzenal', 'quinzena anterior'),
  mensal('Mensal', 'mês anterior');

  final String nome;

  /// Com o que o período é comparado ("vs ...")
  final String comparacao;

  const TipoPeriodo(this.nome, this.comparacao);
}

const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _meses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// AAAA-MM-DD -> DateTime UTC
DateTime dataDeIso(String iso) =>
    DateTime.utc(int.parse(iso.substring(0, 4)), int.parse(iso.substring(5, 7)), int.parse(iso.substring(8, 10)));

/// DateTime -> AAAA-MM-DD
String isoDeData(DateTime data) =>
    '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

String _dd(int n) => n.toString().padLeft(2, '0');

/// dd/MM
String diaMes(DateTime data) => '${_dd(data.day)}/${_dd(data.month)}';

/// dd/MM/AAAA
String dataBr(DateTime data) => '${diaMes(data)}/${data.year}';

/// Seg, Ter, ...
String diaDaSemana(DateTime data) => _diasSemana[data.weekday - 1];

/// Semana de segunda a domingo; quinzenas de 1 a 15 e de 16 ao fim do mês.
class Periodo {
  final TipoPeriodo tipo;
  final DateTime inicio;
  final DateTime fim;

  const Periodo._(this.tipo, this.inicio, this.fim);

  factory Periodo.contendo(TipoPeriodo tipo, DateTime data) {
    final d = DateTime.utc(data.year, data.month, data.day);
    switch (tipo) {
      case TipoPeriodo.diario:
        return Periodo._(tipo, d, d);
      case TipoPeriodo.semanal:
        final segunda = d.subtract(Duration(days: d.weekday - 1));
        return Periodo._(tipo, segunda, segunda.add(const Duration(days: 6)));
      case TipoPeriodo.quinzenal:
        return d.day <= 15
            ? Periodo._(tipo, DateTime.utc(d.year, d.month, 1), DateTime.utc(d.year, d.month, 15))
            : Periodo._(tipo, DateTime.utc(d.year, d.month, 16), DateTime.utc(d.year, d.month + 1, 0));
      case TipoPeriodo.mensal:
        return Periodo._(tipo, DateTime.utc(d.year, d.month, 1), DateTime.utc(d.year, d.month + 1, 0));
    }
  }

  Periodo anterior() => Periodo.contendo(tipo, inicio.subtract(const Duration(days: 1)));

  Periodo proximo() => Periodo.contendo(tipo, fim.add(const Duration(days: 1)));

  /// Período usado na comparação: o dia é comparado com o mesmo dia da semana anterior
  /// (segunda com segunda), porque a operação muda muito entre dia útil e fim de semana.
  Periodo comparacao() =>
      tipo == TipoPeriodo.diario ? Periodo.contendo(tipo, inicio.subtract(const Duration(days: 7))) : anterior();

  String get inicioIso => isoDeData(inicio);
  String get fimIso => isoDeData(fim);

  /// Quantidade de dias do calendário no período
  int get dias => fim.difference(inicio).inDays + 1;

  bool contem(String iso) => iso.compareTo(inicioIso) >= 0 && iso.compareTo(fimIso) <= 0;

  /// Datas do período, em ordem
  List<DateTime> get datas => [for (var i = 0; i < dias; i++) inicio.add(Duration(days: i))];

  String get rotulo {
    switch (tipo) {
      case TipoPeriodo.diario:
        return '${diaDaSemana(inicio)}, ${dataBr(inicio)}';
      case TipoPeriodo.semanal:
        return inicio.year == fim.year ? '${diaMes(inicio)} – ${dataBr(fim)}' : '${dataBr(inicio)} – ${dataBr(fim)}';
      case TipoPeriodo.quinzenal:
        final mes = _meses[inicio.month - 1].substring(0, 3).toLowerCase();
        return '${inicio.day == 1 ? 1 : 2}ª quinzena · $mes/${inicio.year}';
      case TipoPeriodo.mensal:
        return '${_meses[inicio.month - 1]} de ${inicio.year}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.tipo == tipo && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(tipo, inicio, fim);

  @override
  String toString() => 'Periodo(${tipo.name}, $inicioIso a $fimIso)';
}
