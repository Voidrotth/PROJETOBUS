import 'dart:convert';
import 'package:http/http.dart' as http;

class ServicoApi {
  static const String urlBase = 'http://localhost:3000/api';

  // ==================== PAINEL ====================

  static Future<Map<String, dynamic>> buscarPainel() async {
    final resposta = await http.get(Uri.parse('$urlBase/painel/resumo'));
    if (resposta.statusCode == 200) {
      return jsonDecode(resposta.body);
    }
    throw Exception('Erro ao carregar painel');
  }

  // ==================== IMPORTAÇÕES ====================

  static Future<List<Map<String, dynamic>>> buscarImportacoes({String? status}) async {
    String url = '$urlBase/importacoes';
    if (status != null && status.isNotEmpty) {
      url += '?status=$status';
    }
    final resposta = await http.get(Uri.parse(url));
    if (resposta.statusCode == 200) {
      final List<dynamic> dados = jsonDecode(resposta.body);
      return dados.cast<Map<String, dynamic>>();
    }
    throw Exception('Erro ao carregar importações');
  }

  static Future<Map<String, dynamic>> buscarImportacao(String id) async {
    final resposta = await http.get(Uri.parse('$urlBase/importacoes/$id'));
    if (resposta.statusCode == 200) {
      return jsonDecode(resposta.body);
    }
    throw Exception('Erro ao carregar importação');
  }

  static Future<Map<String, dynamic>> atualizarImportacao(
      String id, Map<String, dynamic> dadosExtraidos) async {
    final resposta = await http.put(
      Uri.parse('$urlBase/importacoes/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dadosExtraidos': dadosExtraidos}),
    );
    if (resposta.statusCode == 200) {
      return jsonDecode(resposta.body);
    }
    throw Exception('Erro ao atualizar importação');
  }

  static Future<Map<String, dynamic>> confirmarImportacao(String id) async {
    final resposta = await http.patch(
      Uri.parse('$urlBase/importacoes/$id/confirmar'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resposta.statusCode == 200) {
      return jsonDecode(resposta.body);
    }
    throw Exception(_mensagemDeErro(resposta, 'Erro ao confirmar importação'));
  }

  // Usa a mensagem de erro enviada pelo backend ({"erro": "..."}), se houver
  static String _mensagemDeErro(http.Response resposta, String padrao) {
    try {
      final corpo = jsonDecode(resposta.body);
      if (corpo is Map && corpo['erro'] is String) return corpo['erro'];
    } catch (_) {}
    return padrao;
  }

  static Future<void> rejeitarImportacao(String id) async {
    final resposta = await http.patch(
      Uri.parse('$urlBase/importacoes/$id/rejeitar'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resposta.statusCode != 200) {
      throw Exception('Erro ao rejeitar importação');
    }
  }

  // ==================== OPERAÇÕES ====================

  static Future<Map<String, dynamic>> criarOperacao(Map<String, dynamic> dados) async {
    final resposta = await http.post(
      Uri.parse('$urlBase/operacoes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    if (resposta.statusCode == 201) {
      return jsonDecode(resposta.body);
    }
    throw Exception('Erro ao cadastrar operação');
  }

  static Future<List<Map<String, dynamic>>> buscarOperacoes() async {
    final resposta = await http.get(Uri.parse('$urlBase/operacoes'));
    if (resposta.statusCode == 200) {
      final List<dynamic> dados = jsonDecode(resposta.body);
      return dados.cast<Map<String, dynamic>>();
    }
    throw Exception('Erro ao carregar operações');
  }

  // ==================== WEBHOOK (TESTE) ====================

  static Future<Map<String, dynamic>> enviarEmailWebhook(
      String remetente, String assunto, String texto) async {
    final resposta = await http.post(
      Uri.parse('$urlBase/email/webhook'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': remetente,
        'subject': assunto,
        'text': texto,
      }),
    );
    if (resposta.statusCode == 201) {
      return jsonDecode(resposta.body);
    }
    throw Exception('Erro ao enviar e-mail');
  }
}
