class Operacao {
  final String? id;
  final String linha;
  final String veiculo;
  final String motorista;
  final String cobrador;
  final DateTime? dataOperacao;
  final String horarioSaida;
  final String horarioRecolhimento;
  final double kmInicial;
  final double kmFinal;
  final int passageiros;
  final int viagens;
  final String ocorrencias;
  final String origem;

  Operacao({
    this.id,
    required this.linha,
    required this.veiculo,
    required this.motorista,
    this.cobrador = '',
    this.dataOperacao,
    this.horarioSaida = '',
    this.horarioRecolhimento = '',
    this.kmInicial = 0,
    this.kmFinal = 0,
    this.passageiros = 0,
    this.viagens = 0,
    this.ocorrencias = '',
    this.origem = 'manual',
  });

  factory Operacao.deJson(Map<String, dynamic> json) {
    return Operacao(
      id: json['_id'],
      linha: json['linha'] ?? '',
      veiculo: json['veiculo'] ?? '',
      motorista: json['motorista'] ?? '',
      cobrador: json['cobrador'] ?? '',
      dataOperacao: DateTime.tryParse(json['dataOperacao'] ?? ''),
      horarioSaida: json['horarioSaida'] ?? '',
      horarioRecolhimento: json['horarioRecolhimento'] ?? '',
      kmInicial: (json['kmInicial'] ?? 0).toDouble(),
      kmFinal: (json['kmFinal'] ?? 0).toDouble(),
      passageiros: (json['passageiros'] ?? 0).toInt(),
      viagens: (json['viagens'] ?? 0).toInt(),
      ocorrencias: json['ocorrencias'] ?? '',
      origem: json['origem'] ?? 'manual',
    );
  }

  Map<String, dynamic> paraJson() {
    return {
      'linha': linha,
      'veiculo': veiculo,
      'motorista': motorista,
      'cobrador': cobrador,
      'dataOperacao': dataOperacao?.toIso8601String(),
      'horarioSaida': horarioSaida,
      'horarioRecolhimento': horarioRecolhimento,
      'kmInicial': kmInicial,
      'kmFinal': kmFinal,
      'passageiros': passageiros,
      'viagens': viagens,
      'ocorrencias': ocorrencias,
    };
  }
}
