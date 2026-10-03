import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'sessao.dart';

/// Erro devolvido pelo backend, com a mensagem pronta para mostrar na tela.
class ErroApi implements Exception {
  final String mensagem;
  final int status;

  ErroApi(this.mensagem, this.status);

  @override
  String toString() => mensagem;
}

class ServicoApi {
  // No navegador, o painel é servido pelo próprio backend: a API fica no mesmo endereço (funciona
  // também por um link https, ex.: túnel do cloudflared). Fora disso, informe o endereço com
  // --dart-define=API_URL=http://IP_DO_COMPUTADOR:3000/api
  static const String _apiInformada = String.fromEnvironment('API_URL');
  static final String urlBase = _apiInformada.isNotEmpty
      ? _apiInformada
      : (kIsWeb ? '${Uri.base.origin}/api' : 'http://localhost:3000/api');

  /// Endereço do Socket.IO (mesmo servidor, sem o /api)
  static String get urlServidor => urlBase.replaceFirst(RegExp(r'/api/?$'), '');

  // ==================== REQUISIÇÕES AUTENTICADAS ====================

  static Future<dynamic> _requisitar(String metodo, String caminho,
      {Object? corpo, Duration tempoLimite = const Duration(seconds: 20)}) async {
    final requisicao = http.Request(metodo, Uri.parse('$urlBase$caminho'))
      ..headers['Content-Type'] = 'application/json';
    if (Sessao.token != null) requisicao.headers['Authorization'] = 'Bearer ${Sessao.token}';
    if (corpo != null) requisicao.body = jsonEncode(corpo);

    final resposta = await http.Response.fromStream(await requisicao.send().timeout(tempoLimite));

    if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
      return resposta.body.isEmpty ? null : jsonDecode(resposta.body);
    }
    if (resposta.statusCode == 401 && Sessao.token != null) {
      await Sessao.sair(expirou: true);
    }
    throw ErroApi(_mensagemDeErro(resposta, 'Erro ${resposta.statusCode}'), resposta.statusCode);
  }

  static List<Map<String, dynamic>> _lista(dynamic dados) =>
      (dados as List).cast<Map<String, dynamic>>();

  // ==================== LOGIN ====================

  static Future<void> entrar(String email, String senha) async {
    final dados = await _requisitar('POST', '/auth/login', corpo: {'email': email, 'senha': senha});
    await Sessao.entrar(dados['token'], Map<String, dynamic>.from(dados['usuario']));
  }

  // ==================== FROTA (VEÍCULOS E MOTORISTAS) ====================

  static Future<List<Map<String, dynamic>>> listarVeiculos() async =>
      _lista(await _requisitar('GET', '/veiculos'));

  static Future<Map<String, dynamic>> salvarVeiculo(Map<String, dynamic> dados, {String? id}) async =>
      await _requisitar(id == null ? 'POST' : 'PUT', id == null ? '/veiculos' : '/veiculos/$id', corpo: dados);

  static Future<List<Map<String, dynamic>>> listarMotoristas() async =>
      _lista(await _requisitar('GET', '/usuarios?papel=motorista'));

  static Future<Map<String, dynamic>> salvarUsuario(Map<String, dynamic> dados, {String? id}) async =>
      await _requisitar(id == null ? 'POST' : 'PUT', id == null ? '/usuarios' : '/usuarios/$id', corpo: dados);


  // ==================== VIAGENS ====================

  /// Linhas que existem nos relatórios importados (ex.: ["01", "02", ...])
  static Future<List<String>> linhasDisponiveis() async =>
      ((await _requisitar('GET', '/viagens/opcoes'))['linhas'] as List).cast<String>();

  /// dados: placa, linha, kmInicial (o resto da viagem vem dos relatórios)
  static Future<Map<String, dynamic>> iniciarViagem(Map<String, dynamic> dados) async =>
      await _requisitar('POST', '/viagens/iniciar', corpo: dados);

  static Future<Map<String, dynamic>?> viagemAtual() async => await _requisitar('GET', '/viagens/atual');

  static Future<Map<String, dynamic>> encerrarViagem(String viagemId, Map<String, dynamic> fechamento) async =>
      await _requisitar('POST', '/viagens/$viagemId/encerrar', corpo: fechamento);

  static Future<void> enviarPosicoes(String viagemId, List<Map<String, dynamic>> posicoes) async {
    await _requisitar('POST', '/localizacao',
        corpo: {'viagemId': viagemId, 'posicoes': posicoes}, tempoLimite: const Duration(seconds: 15));
  }

  /// Km rodados (hodômetro) e combustível estimado por ônibus no período (AAAA-MM-DD)
  static Future<Map<String, dynamic>> kmPorVeiculo(String inicio, String fim) async =>
      await _requisitar('GET', Uri(path: '/viagens/km', queryParameters: {'inicio': inicio, 'fim': fim}).toString());

  static Future<List<Map<String, dynamic>>> viagensAoVivo() async =>
      _lista(await _requisitar('GET', '/viagens/ao-vivo'));

  static Future<List<Map<String, dynamic>>> trajeto(String viagemId) async =>
      _lista(await _requisitar('GET', '/viagens/$viagemId/trajeto'));

  // ==================== VERIFICAÇÃO (RELATÓRIOS DO VERIFICADOR) ====================

  /// Filtros: inicio e fim (AAAA-MM-DD) e tipos (util, nao_util, feriado separados por vírgula)
  static Future<Map<String, dynamic>> buscarIndicadores(Map<String, String> filtros) async =>
      await _requisitar('GET', Uri(path: '/indicadores', queryParameters: filtros).toString());

  /// Operação a partir das viagens: por linha, hora, veículo, turnos e não cumpridas.
  /// Mesmos filtros da Verificação, mais linha (ex.: 01)
  static Future<Map<String, dynamic>> buscarOperacao(Map<String, String> filtros) async =>
      await _requisitar('GET', Uri(path: '/indicadores/operacao', queryParameters: filtros).toString());

  /// Pesquisa de viagens: filtros da operação mais prefixo, sentido (ida|volta), hora e pagina
  static Future<Map<String, dynamic>> pesquisarViagens(Map<String, String> filtros) async =>
      await _requisitar('GET', Uri(path: '/indicadores/viagens', queryParameters: filtros).toString());

  static Future<Uint8List> _baixar(String caminho, Map<String, String> filtros) async {
    final resposta = await http.get(
      Uri.parse('$urlBase${Uri(path: caminho, queryParameters: filtros)}'),
      headers: {'Authorization': 'Bearer ${Sessao.token}'},
    );
    if (resposta.statusCode != 200) {
      throw ErroApi(_mensagemDeErro(resposta, 'Erro ao exportar'), resposta.statusCode);
    }
    return resposta.bodyBytes;
  }

  /// Mesmos filtros da consulta, mais formato (csv|xlsx) e escopo (tudo|quilometragem)
  static Future<Uint8List> exportarIndicadores(Map<String, String> filtros) =>
      _baixar('/indicadores/exportar', filtros);

  /// Página HTML pronta para imprimir ou salvar em PDF
  static Future<Uint8List> relatorioQuilometragem(Map<String, String> filtros) =>
      _baixar('/indicadores/relatorio-quilometragem', filtros);

  static Future<void> salvarFeriado(String data, String nome) async =>
      await _requisitar('PUT', '/indicadores/feriados/$data', corpo: {'nome': nome});

  static Future<void> excluirFeriado(String data) async =>
      await _requisitar('DELETE', '/indicadores/feriados/$data');

  // ==================== ENVIO DE DADOS ====================

  /// Guarda um arquivo (.html do Smart Report ou .csv) no servidor; [envio] agrupa os arquivos mandados juntos
  static Future<void> enviarArquivo(String envio, String nome, Uint8List bytes) async {
    final resposta = await http.post(
      Uri.parse('$urlBase${Uri(path: '/indicadores/arquivos', queryParameters: {'envio': envio, 'nome': nome})}'),
      headers: {'Authorization': 'Bearer ${Sessao.token}', 'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    if (resposta.statusCode != 201) {
      throw ErroApi('$nome: ${_mensagemDeErro(resposta, 'erro ao enviar')}', resposta.statusCode);
    }
  }

  /// Lê tudo que já foi enviado e atualiza o painel (a leitura dos arquivos grandes leva alguns segundos)
  static Future<Map<String, dynamic>> processarDados() async =>
      await _requisitar('POST', '/indicadores/processar', tempoLimite: const Duration(minutes: 3));

  /// Arquivos lidos e conferências da última leitura (nulo se nada foi processado ainda)
  static Future<Map<String, dynamic>?> ultimaImportacaoDados() async =>
      await _requisitar('GET', '/indicadores/importacao');

  // ==================== PAINEL ====================

  static Future<Map<String, dynamic>> buscarPainel() async {
    final resposta = await http.get(Uri.parse('$urlBase/painel/resumo'));
    if (resposta.statusCode == 200) {
      return jsonDecode(resposta.body);
    }
    throw Exception('Erro ao carregar painel');
  }

  // Usa a mensagem de erro enviada pelo backend ({"erro": "..."}), se houver
  static String _mensagemDeErro(http.Response resposta, String padrao) {
    try {
      final corpo = jsonDecode(resposta.body);
      if (corpo is Map && corpo['erro'] is String) return corpo['erro'];
    } catch (_) {}
    return padrao;
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
}
