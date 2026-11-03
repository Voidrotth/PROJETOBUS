import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Usuário logado e token JWT, guardados no aparelho para não pedir login toda vez.
class Sessao {
  static const _chaveToken = 'sessao_token';
  static const _chaveUsuario = 'sessao_usuario';

  static String? token;
  static Map<String, dynamic>? usuario;

  /// Chamado quando o backend responde 401 (token expirado): o app volta ao login.
  static VoidCallback? aoExpirar;

  static bool get logado => token != null;
  /// Administração ou computador da SEMOB (que só lê os indicadores)
  static bool get podeVerPainel => logado && ['admin', 'computador'].contains(usuario?['papel']);
  static String get nome => usuario?['nome'] ?? '';

  static Future<void> carregar() async {
    // Computador da SEMOB: http://ENDERECO/?semob=CHAVE (CHAVE_COMPUTADOR_SEMOB do .env do backend). Não salva nada.
    final chaveSemob = kIsWeb ? Uri.base.queryParameters['semob'] : null;
    if (chaveSemob != null && chaveSemob.isNotEmpty) {
      token = chaveSemob;
      usuario = {'papel': 'computador', 'nome': 'Computador da SEMOB'};
      return;
    }
    final preferencias = await SharedPreferences.getInstance();
    token = preferencias.getString(_chaveToken);
    final usuarioSalvo = preferencias.getString(_chaveUsuario);
    usuario = usuarioSalvo == null ? null : Map<String, dynamic>.from(jsonDecode(usuarioSalvo));
    if (usuario == null) token = null;
  }

  static Future<void> entrar(String novoToken, Map<String, dynamic> novoUsuario) async {
    token = novoToken;
    usuario = novoUsuario;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_chaveToken, novoToken);
    await preferencias.setString(_chaveUsuario, jsonEncode(novoUsuario));
  }

  static Future<void> sair({bool expirou = false}) async {
    token = null;
    usuario = null;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_chaveToken);
    await preferencias.remove(_chaveUsuario);
    if (expirou) aoExpirar?.call();
  }
}
