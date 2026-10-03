import 'package:flutter/material.dart';
import '../../servicos/rastreador_gps.dart';
import '../../servicos/servico_api.dart';

/// Encerramento: o motorista informa só o hodômetro final; o sistema calcula os km rodados.
/// Passageiros, receita etc. vêm dos relatórios do Smart Report.
class TelaEncerramento extends StatefulWidget {
  final Map<String, dynamic> viagem;

  const TelaEncerramento({super.key, required this.viagem});

  @override
  State<TelaEncerramento> createState() => _TelaEncerramentoEstado();
}

class _TelaEncerramentoEstado extends State<TelaEncerramento> {
  final _chaveFormulario = GlobalKey<FormState>();
  final _kmFinalCtrl = TextEditingController();
  bool _enviando = false;

  double get _kmInicial => (widget.viagem['kmInicial'] as num?)?.toDouble() ?? 0;
  double? get _kmFinal => double.tryParse(_kmFinalCtrl.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _kmFinalCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_chaveFormulario.currentState!.validate()) return;
    setState(() => _enviando = true);

    final rastreador = RastreadorGps.instancia;
    try {
      // Manda o que estiver na fila antes de fechar, para o trajeto ficar completo
      await rastreador.enviarFila();
      await ServicoApi.encerrarViagem(widget.viagem['_id'], {'kmFinal': _kmFinal});
      await rastreador.enviarFila();
      await rastreador.parar();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viagem encerrada'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ErroApi ? e.mensagem : 'Sem conexão. Tente de novo.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encerrar viagem')),
      body: Form(
        key: _chaveFormulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _kmFinalCtrl,
              decoration: const InputDecoration(labelText: 'Km do hodômetro no final', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (_) {
                final km = _kmFinal;
                if (km == null) return 'Informe o km do hodômetro';
                if (km < _kmInicial) return 'Menor que o hodômetro do início (${_kmInicial.toStringAsFixed(1)} km)';
                return null;
              },
            ),
            const SizedBox(height: 8),
            // Km rodados = hodômetro final − inicial
            Text(
              _kmFinal == null || _kmFinal! < _kmInicial
                  ? 'Hodômetro no início: ${_kmInicial.toStringAsFixed(1)} km'
                  : 'Rodou ${(_kmFinal! - _kmInicial).toStringAsFixed(1)} km nesta viagem',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _enviando ? null : _confirmar,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.check),
              label: Text(_enviando ? 'Enviando...' : 'Confirmar e encerrar', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
