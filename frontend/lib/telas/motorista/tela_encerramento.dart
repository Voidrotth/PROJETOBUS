import 'package:flutter/material.dart';
import '../../servicos/rastreador_gps.dart';
import '../../servicos/servico_api.dart';

/// Fechamento do dia: km, passageiros e valores recebidos. Vai para o painel ao confirmar.
class TelaEncerramento extends StatefulWidget {
  final Map<String, dynamic> viagem;

  const TelaEncerramento({super.key, required this.viagem});

  @override
  State<TelaEncerramento> createState() => _TelaEncerramentoEstado();
}

class _TelaEncerramentoEstado extends State<TelaEncerramento> {
  final _chaveFormulario = GlobalKey<FormState>();
  final _kmFinalCtrl = TextEditingController();
  final _passageirosCtrl = TextEditingController();
  final _voltasCtrl = TextEditingController();
  final _dinheiroCtrl = TextEditingController();
  final _cartaoCtrl = TextEditingController();
  final _pixCtrl = TextEditingController();
  final _gratuidadesCtrl = TextEditingController();
  final _ocorrenciasCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    for (final ctrl in [
      _kmFinalCtrl, _passageirosCtrl, _voltasCtrl, _dinheiroCtrl,
      _cartaoCtrl, _pixCtrl, _gratuidadesCtrl, _ocorrenciasCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  double _numero(TextEditingController ctrl) => double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;

  double get _total => _numero(_dinheiroCtrl) + _numero(_cartaoCtrl) + _numero(_pixCtrl);

  Future<void> _confirmar() async {
    if (!_chaveFormulario.currentState!.validate()) return;
    setState(() => _enviando = true);

    final rastreador = RastreadorGps.instancia;
    try {
      // Manda o que estiver na fila antes de fechar, para o trajeto e o km do GPS ficarem completos
      await rastreador.enviarFila();
      await ServicoApi.encerrarViagem(widget.viagem['_id'], {
        'kmFinal': _numero(_kmFinalCtrl),
        'passageiros': _numero(_passageirosCtrl).toInt(),
        'voltas': _numero(_voltasCtrl).toInt(),
        'ocorrencias': _ocorrenciasCtrl.text.trim(),
        'pagamento': {
          'dinheiro': _numero(_dinheiroCtrl),
          'cartao': _numero(_cartaoCtrl),
          'pix': _numero(_pixCtrl),
          'gratuidades': _numero(_gratuidadesCtrl).toInt(),
        },
      });
      await rastreador.enviarFila();
      await rastreador.parar();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viagem encerrada e enviada ao painel'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ErroApi ? e.mensagem : 'Sem conexão. Os dados continuam aqui: tente de novo.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campo(TextEditingController ctrl, String rotulo,
      {bool decimal = false, bool obrigatorio = false, String? prefixo}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: rotulo, prefixText: prefixo, border: const OutlineInputBorder()),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          if (obrigatorio && (v == null || v.trim().isEmpty)) return 'Obrigatório';
          if (v != null && v.trim().isNotEmpty && double.tryParse(v.replaceAll(',', '.')) == null) {
            return 'Número inválido';
          }
          return null;
        },
      ),
    );
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
            Text('Operação', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _campo(_kmFinalCtrl, 'Km final', decimal: true, obrigatorio: true),
            Row(
              children: [
                Expanded(child: _campo(_passageirosCtrl, 'Passageiros')),
                const SizedBox(width: 12),
                Expanded(child: _campo(_voltasCtrl, 'Viagens (voltas)')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pagamentos recebidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _campo(_dinheiroCtrl, 'Dinheiro', decimal: true, prefixo: 'R\$ '),
            _campo(_cartaoCtrl, 'Cartão / bilhete eletrônico', decimal: true, prefixo: 'R\$ '),
            _campo(_pixCtrl, 'Pix', decimal: true, prefixo: 'R\$ '),
            _campo(_gratuidadesCtrl, 'Gratuidades (quantidade)'),
            Text('Total: R\$ ${_total.toStringAsFixed(2).replaceAll('.', ',')}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ocorrenciasCtrl,
              decoration: const InputDecoration(labelText: 'Ocorrências', border: OutlineInputBorder()),
              maxLines: 3,
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
