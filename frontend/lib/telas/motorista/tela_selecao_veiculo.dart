import 'package:flutter/material.dart';
import '../../servicos/rastreador_gps.dart';
import '../../servicos/servico_api.dart';

class TelaSelecaoVeiculo extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> aoIniciar;

  const TelaSelecaoVeiculo({super.key, required this.aoIniciar});

  @override
  State<TelaSelecaoVeiculo> createState() => _TelaSelecaoVeiculoEstado();
}

class _TelaSelecaoVeiculoEstado extends State<TelaSelecaoVeiculo> {
  final _linhaCtrl = TextEditingController();
  final _kmInicialCtrl = TextEditingController();
  List<Map<String, dynamic>> _veiculos = [];
  Map<String, dynamic>? _selecionado;
  bool _carregando = true;
  bool _iniciando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  @override
  void dispose() {
    _linhaCtrl.dispose();
    _kmInicialCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarVeiculos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final veiculos = await ServicoApi.listarVeiculos();
      if (mounted) setState(() => _veiculos = veiculos);
    } catch (e) {
      if (mounted) setState(() => _erro = e is ErroApi ? e.mensagem : 'Sem conexão com o servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _selecionar(Map<String, dynamic> veiculo) {
    setState(() {
      _selecionado = veiculo;
      _kmInicialCtrl.text = '${veiculo['hodometro'] ?? 0}';
    });
  }

  Future<void> _iniciar() async {
    final veiculo = _selecionado;
    if (veiculo == null) return;
    if (_linhaCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe a linha');
      return;
    }

    setState(() => _iniciando = true);
    try {
      final erroPermissao = await RastreadorGps.verificarPermissao();
      if (erroPermissao != null) {
        _mostrarErro(erroPermissao);
        return;
      }
      final viagem = await ServicoApi.iniciarViagem(
        veiculo['_id'],
        _linhaCtrl.text.trim(),
        double.tryParse(_kmInicialCtrl.text.replaceAll(',', '.')),
      );
      viagem['veiculo'] = veiculo;
      widget.aoIniciar(viagem);
    } catch (e) {
      // Já existe viagem aberta deste motorista: retoma em vez de travar
      final aberta = (e is ErroApi && e.status == 409) ? await ServicoApi.viagemAtual().catchError((_) => null) : null;
      if (aberta != null) {
        widget.aoIniciar(aberta);
      } else {
        _mostrarErro(e is ErroApi ? e.mensagem : 'Sem conexão com o servidor');
      }
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _carregarVeiculos, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Escolha o veículo', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: _veiculos.isEmpty
              ? const Center(child: Text('Nenhum veículo cadastrado'))
              : RefreshIndicator(
                  onRefresh: _carregarVeiculos,
                  child: ListView.builder(
                    itemCount: _veiculos.length,
                    itemBuilder: (context, indice) {
                      final veiculo = _veiculos[indice];
                      final emUso = veiculo['emUso'] == true;
                      final selecionado = _selecionado?['_id'] == veiculo['_id'];
                      return ListTile(
                        enabled: !emUso,
                        selected: selecionado,
                        leading: Icon(Icons.directions_bus, color: emUso ? Colors.grey : Colors.blue),
                        title: Text(veiculo['placa'] ?? ''),
                        subtitle: Text([
                          if ((veiculo['prefixo'] ?? '').isNotEmpty) 'Prefixo ${veiculo['prefixo']}',
                          if (emUso) 'Em viagem',
                        ].join(' · ')),
                        trailing: selecionado ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                        onTap: emUso ? null : () => _selecionar(veiculo),
                      );
                    },
                  ),
                ),
        ),
        if (_selecionado != null)
          Material(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _linhaCtrl,
                          decoration: const InputDecoration(labelText: 'Linha', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _kmInicialCtrl,
                          decoration: const InputDecoration(labelText: 'Km inicial', border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _iniciando ? null : _iniciar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Colors.green),
                    icon: const Icon(Icons.play_arrow, size: 32),
                    label: Text(_iniciando ? 'Iniciando...' : 'INICIAR VIAGEM', style: const TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
