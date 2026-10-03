import 'package:flutter/material.dart';
import '../../servicos/servico_api.dart';
import '../../servicos/sessao.dart';
import 'tela_selecao_veiculo.dart';
import 'tela_viagem.dart';

/// Entrada do motorista: retoma a viagem aberta (se houver) ou mostra a seleção de veículo.
class TelaMotorista extends StatefulWidget {
  final VoidCallback aoSair;

  const TelaMotorista({super.key, required this.aoSair});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaEstado();
}

class _TelaMotoristaEstado extends State<TelaMotorista> {
  Map<String, dynamic>? _viagem;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarViagemAtual();
  }

  Future<void> _carregarViagemAtual() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final viagem = await ServicoApi.viagemAtual();
      if (mounted) setState(() => _viagem = viagem);
    } catch (e) {
      if (mounted) setState(() => _erro = e is ErroApi ? e.mensagem : 'Sem conexão com o servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_carregando) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_erro != null) {
      corpo = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_erro!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _carregarViagemAtual,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    } else if (_viagem != null) {
      corpo = TelaViagem(viagem: _viagem!, aoEncerrar: () => setState(() => _viagem = null));
    } else {
      corpo = TelaSelecaoVeiculo(aoIniciar: (viagem) => setState(() => _viagem = viagem));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${Sessao.nome}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_viagem == null)
            IconButton(onPressed: widget.aoSair, icon: const Icon(Icons.logout), tooltip: 'Sair'),
        ],
      ),
      body: corpo,
    );
  }
}
