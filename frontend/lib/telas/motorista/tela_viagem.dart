import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../servicos/rastreador_gps.dart';
import 'tela_encerramento.dart';

/// Viagem em andamento: mostra o status do GPS e do envio, e o botão de encerrar.
class TelaViagem extends StatefulWidget {
  final Map<String, dynamic> viagem;
  final VoidCallback aoEncerrar;

  const TelaViagem({super.key, required this.viagem, required this.aoEncerrar});

  @override
  State<TelaViagem> createState() => _TelaViagemEstado();
}

class _TelaViagemEstado extends State<TelaViagem> {
  final _rastreador = RastreadorGps.instancia;
  late final DateTime _inicio;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _inicio = DateTime.tryParse(widget.viagem['inicio'] ?? '')?.toLocal() ?? DateTime.now();
    _rastreador.iniciar(widget.viagem['_id']);
    // Atualiza o tempo de viagem na tela
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _abrirEncerramento() async {
    final encerrou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TelaEncerramento(viagem: widget.viagem)),
    );
    if (encerrou == true) widget.aoEncerrar();
  }

  String _duracao() {
    final d = DateTime.now().difference(_inicio);
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';
  }

  @override
  Widget build(BuildContext context) {
    final veiculo = widget.viagem['veiculo'] as Map<String, dynamic>? ?? {};

    return ListenableBuilder(
      listenable: _rastreador,
      builder: (context, _) {
        final posicao = _rastreador.ultimaPosicao;
        final ultimoEnvio = _rastreador.ultimoEnvio;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.directions_bus, size: 40, color: Colors.green),
                title: Text('Linha ${widget.viagem['linha']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${veiculo['prefixo'] ?? ''} ${veiculo['placa'] ?? ''}\n'
                    'Início ${DateFormat('HH:mm').format(_inicio)} · ${_duracao()} em viagem'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 8),
            _linhaStatus(
              icone: _rastreador.rastreando ? Icons.gps_fixed : Icons.gps_off,
              cor: _rastreador.erro != null ? Colors.red : (_rastreador.rastreando ? Colors.green : Colors.grey),
              titulo: _rastreador.erro ?? (posicao == null ? 'Aguardando sinal do GPS...' : 'GPS ativo'),
              detalhe: posicao == null
                  ? null
                  : '${posicao.latitude.toStringAsFixed(5)}, ${posicao.longitude.toStringAsFixed(5)}'
                      ' · ${(posicao.speed * 3.6).toStringAsFixed(0)} km/h · precisão ${posicao.accuracy.toStringAsFixed(0)} m',
            ),
            _linhaStatus(
              icone: _rastreador.conectado ? Icons.cloud_done : Icons.cloud_off,
              cor: _rastreador.conectado ? Colors.green : Colors.orange,
              titulo: _rastreador.conectado ? 'Conectado' : 'Sem conexão: guardando posições no celular',
              detalhe: [
                '${_rastreador.pendentes} posição(ões) aguardando envio',
                if (ultimoEnvio != null) 'último envio ${DateFormat('HH:mm:ss').format(ultimoEnvio)}',
              ].join(' · '),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _abrirEncerramento,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60), backgroundColor: Colors.red),
              icon: const Icon(Icons.stop, size: 32),
              label: const Text('ENCERRAR VIAGEM', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pode bloquear a tela: a localização continua sendo enviada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _linhaStatus({required IconData icone, required Color cor, required String titulo, String? detalhe}) {
    return Card(
      child: ListTile(
        leading: Icon(icone, color: cor, size: 32),
        title: Text(titulo),
        subtitle: detalhe == null ? null : Text(detalhe),
      ),
    );
  }
}
