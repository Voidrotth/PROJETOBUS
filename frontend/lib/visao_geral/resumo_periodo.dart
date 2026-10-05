import 'periodo.dart';

/// Viagens programadas e realizadas de um turno no período
class Turno {
  final String nome;
  final double programadas;
  final double realizadas;

  const Turno(this.nome, this.programadas, this.realizadas);

  double? get cumprimento => programadas > 0 ? realizadas / programadas : null;
}

/// Soma de um campo nos dias que têm o dado; nulo quando nenhum dia tem (mostrado como "sem dado", nunca 0).
double? somaCampo(Iterable<Map<String, dynamic>> dias, String campo) {
  double? soma;
  for (final dia in dias) {
    final valor = dia[campo] as num?;
    if (valor != null) soma = (soma ?? 0) + valor.toDouble();
  }
  return soma;
}

/// Acrescenta aos dias de GET /api/indicadores os campos calculados que o painel usa:
/// receita = créditos vendidos + receita de catraca (nula só se as duas faltarem).
List<Map<String, dynamic>> prepararDias(List<Map<String, dynamic>> dias) => [
      for (final dia in dias)
        {
          ...dia,
          'receita': dia['vendas'] == null && dia['receitaCatraca'] == null
              ? null
              : ((dia['vendas'] as num?) ?? 0) + ((dia['receitaCatraca'] as num?) ?? 0),
        }
    ];

/// Os 5 indicadores do painel (quilometragem, viagens, pagantes, não pagantes e financeiro)
/// somados para um período, a partir dos dias de GET /api/indicadores.
class ResumoPeriodo {
  final Periodo periodo;

  /// Dias do período que existem nos relatórios
  final List<Map<String, dynamic>> dias;

  const ResumoPeriodo._(this.periodo, this.dias);

  factory ResumoPeriodo.de(List<Map<String, dynamic>> todos, Periodo periodo) =>
      ResumoPeriodo._(periodo, [for (final dia in todos) if (periodo.contem(dia['data'] as String)) dia]);

  double? _soma(String campo) => somaCampo(dias, campo);

  /// Dias com o campo preenchido (cada grupo de dados começa numa data diferente)
  int diasCom(String campo) => dias.where((d) => d[campo] != null).length;

  // Quilometragem
  double? get kmTotal => _soma('kmTotal');
  double? get kmProdutiva => _soma('kmProdutiva');
  double? get kmImprodutiva => _soma('kmImprodutiva');

  // Viagens
  double? get viagensRealizadas => _soma('viagensRealizadas');
  double? get viagensProgramadas => _soma('viagensProgramadas');
  double? get cumprimento {
    final programadas = viagensProgramadas;
    final realizadas = viagensRealizadas;
    return programadas == null || realizadas == null || programadas == 0 ? null : realizadas / programadas;
  }

  // Passageiros
  double? get pagantes => _soma('pagantes');
  double? get catraca => _soma('catraca');
  double? get antecipados => _soma('antecipados');
  double? get naoPagantes => _soma('naoPagantes');
  double? get passageiros => _soma('passageiros');
  double? get percentualNaoPagantes {
    final total = passageiros;
    final gratuitos = naoPagantes;
    return total == null || gratuitos == null || total == 0 ? null : gratuitos / total;
  }

  // Financeiro (R$): créditos vendidos antecipadamente + receita de catraca (esta só vem por planilha)
  double? get vendas => _soma('vendas');
  double? get utilizacao => _soma('utilizacao');
  double? get receitaCatraca => _soma('receitaCatraca');
  /// Receita total (campo 'receita' criado por [prepararDias])
  double? get receita => _soma('receita');

  /// Cumprimento por turno (o relatório não informa os horários de cada turno)
  List<Turno>? get turnos {
    final lista = <Turno>[];
    for (final (campo, nome) in [('manha', 'Manhã'), ('tarde', 'Tarde'), ('noite', 'Noite')]) {
      final programadas = _soma('${campo}Programadas');
      final realizadas = _soma('${campo}Realizadas');
      if (programadas != null && realizadas != null) lista.add(Turno(nome, programadas, realizadas));
    }
    return lista.isEmpty ? null : lista;
  }

  /// Variação da média diária de [campo] contra outro período (ex.: +0,032 = +3,2%).
  /// Usa a média por dia com dado para que mês de 30 e de 31 dias, ou um período ainda
  /// incompleto, fiquem comparáveis. Nulo se faltar dado em qualquer um dos dois.
  double? variacao(ResumoPeriodo outro, String campo) {
    final atual = _soma(campo);
    final anterior = outro._soma(campo);
    final diasAtual = diasCom(campo);
    final diasAnterior = outro.diasCom(campo);
    if (atual == null || anterior == null || diasAtual == 0 || diasAnterior == 0 || anterior == 0) return null;
    return (atual / diasAtual) / (anterior / diasAnterior) - 1;
  }
}
