import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../servicos/rastreador_gps.dart';
import '../../servicos/servico_api.dart';

/// "Sou motorista": só nome, placa e o botão de transmitir a localização (sem login).
/// O ônibus aparece na aba "Ao vivo" do painel. Se o app fechar, a transmissão volta ao abrir de novo.
class TelaTransmissao extends StatefulWidget {
  const TelaTransmissao({super.key});

  @override
  State<TelaTransmissao> createState() => _TelaTransmissaoEstado();
}

class _TelaTransmissaoEstado extends State<TelaTransmissao> {
  static const _chave = 'transmissao';

  final _formulario = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _rastreador = RastreadorGps.instancia;

  String? _viagemId;
  String? _token;
  bool _ocupado = false;
  String? _erro;

  bool get _transmitindo => _viagemId != null;

  @override
  void initState() {
    super.initState();
    _restaurar();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  // Lembra nome e placa; se havia transmissão aberta, retoma
  Future<void> _restaurar() async {
    final salvo = (await SharedPreferences.getInstance()).getString(_chave);
    if (salvo == null) return;
    final dados = Map<String, dynamic>.from(jsonDecode(salvo));
    _nomeCtrl.text = dados['nome'] ?? '';
    _placaCtrl.text = dados['placa'] ?? '';
    if (dados['viagemId'] != null) await _iniciar();
  }

  Future<void> _salvar() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_chave, jsonEncode({
      'nome': _nomeCtrl.text.trim(),
      'placa': _placaCtrl.text.trim(),
      'viagemId': _viagemId,
    }));
  }

  Future<String> _abrirNoServidor() async {
    final dados = await ServicoApi.iniciarTransmissao(_nomeCtrl.text.trim(), _placaCtrl.text.trim());
    _viagemId = dados['viagemId'] as String;
    _placaCtrl.text = dados['veiculo']['placa'];
    return _token = dados['token'] as String;
  }

  Future<void> _iniciar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final semPermissao = await RastreadorGps.verificarPermissao();
      if (semPermissao != null) throw semPermissao;
      final token = await _abrirNoServidor();
      await _rastreador.iniciar(_viagemId!, token: token, renovarToken: _abrirNoServidor);
      await _salvar();
    } catch (e) {
      _viagemId = null;
      _erro = e is ErroApi ? e.mensagem : e.toString();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _parar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await _rastreador.enviarFila(); // manda o que ainda está na fila antes de fechar
      await ServicoApi.encerrarViagem(_viagemId!, {}, token: _token);
      await _rastreador.parar();
      _viagemId = null;
      _token = null;
      await _salvar();
    } catch (e) {
      _erro = e is ErroApi ? e.mensagem : 'Sem conexão. Tente parar de novo.';
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sou motorista')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nomeCtrl,
                    enabled: !_transmitindo,
                    decoration: const InputDecoration(labelText: 'Nome do motorista', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _placaCtrl,
                    enabled: !_transmitindo,
                    decoration: const InputDecoration(
                      labelText: 'Placa do ônibus',
                      hintText: 'ABC1D23',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length != 7)
                        ? 'Placa com 7 letras/números (ex.: ABC1234 ou ABC1D23)'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _ocupado ? null : (_transmitindo ? _parar : _iniciar),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      backgroundColor: _transmitindo ? const Color(0xFFD03B3B) : null,
                    ),
                    icon: _ocupado
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_transmitindo ? Icons.stop_circle : Icons.gps_fixed),
                    label: Text(_transmitindo ? 'Parar transmissão' : 'Transmitir localização',
                        style: const TextStyle(fontSize: 18)),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 16),
                    Text(_erro!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ],
                  if (_transmitindo) ...[
                    const SizedBox(height: 24),
                    ListenableBuilder(listenable: _rastreador, builder: (context, _) => _status()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Situação da transmissão: ícone + texto (não só a cor)
  Widget _status() {
    final posicao = _rastreador.ultimaPosicao;
    final hora = DateFormat('HH:mm:ss');
    final linhas = <(IconData, Color, String)>[
      _rastreador.conectado
          ? (Icons.cloud_done, const Color(0xFF0CA30C), 'Transmitindo para o painel')
          : (Icons.cloud_off, const Color(0xFFFAB219), 'Sem conexão: as posições ficam guardadas e vão quando voltar'),
      posicao == null
          ? (Icons.gps_not_fixed, Colors.black54, 'Aguardando sinal do GPS…')
          : (Icons.gps_fixed, Colors.blue, 'Posição de ${hora.format(posicao.timestamp.toLocal())} (precisão ${posicao.accuracy.round()} m)'),
      if (_rastreador.ultimoEnvio != null) (Icons.send, Colors.black54, 'Último envio: ${hora.format(_rastreador.ultimoEnvio!)}'),
      if (_rastreador.pendentes > 0) (Icons.schedule, Colors.black54, '${_rastreador.pendentes} posição(ões) aguardando envio'),
      if (_rastreador.erro != null) (Icons.error, const Color(0xFFD03B3B), _rastreador.erro!),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icone, cor, texto) in linhas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [Icon(icone, color: cor, size: 20), const SizedBox(width: 8), Expanded(child: Text(texto))]),
              ),
            const SizedBox(height: 8),
            const Text('Mantenha esta tela aberta durante a viagem.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
