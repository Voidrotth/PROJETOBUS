class Importacao {
  final String id;
  final String origem;
  final String remetente;
  final String assunto;
  final String conteudoOriginal;
  final Map<String, dynamic> dadosExtraidos;
  final String status;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  Importacao({
    required this.id,
    required this.origem,
    required this.remetente,
    required this.assunto,
    required this.conteudoOriginal,
    required this.dadosExtraidos,
    required this.status,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory Importacao.deJson(Map<String, dynamic> json) {
    return Importacao(
      id: json['_id'] ?? '',
      origem: json['origem'] ?? '',
      remetente: json['remetente'] ?? '',
      assunto: json['assunto'] ?? '',
      conteudoOriginal: json['conteudoOriginal'] ?? '',
      dadosExtraidos: Map<String, dynamic>.from(json['dadosExtraidos'] ?? {}),
      status: json['status'] ?? 'pendente',
      criadoEm: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      atualizadoEm: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
