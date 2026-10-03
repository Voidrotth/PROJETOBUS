import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../servicos/rastreador_gps.dart';
import '../../servicos/servico_api.dart';

/// Antes de transmitir a localização o motorista informa só placa, linha e hodômetro.
/// O motorista vem do login (matrícula); o resto da viagem vem dos relatórios do Smart Report.
class TelaSelecaoVeiculo extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> aoIniciar;

  const TelaSelecaoVeiculo({super.key, required this.aoIniciar});

  @override
  State<TelaSelecaoVeiculo> createState() => _TelaSelecaoVeiculoEstado();
}

class _TelaSelecaoVeiculoEstado extends State<TelaSelecaoVeiculo> {
  static const _chavePlaca = 'ultima_placa';

  final _formulario = GlobalKey<FormState>();
  final _placaCtrl = TextEditingController();
  final _linhaCtrl = TextEditingController(); // só quando ainda não há linhas nos relatórios
  final _kmCtrl = TextEditingController();

  List<String> _linhas = [];
  String? _linha;
  bool _iniciando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in [_placaCtrl, _linhaCtrl, _kmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // Linhas dos relatórios e a última placa usada neste aparelho
  Future<void> _carregar() async {
    final preferencias = await SharedPreferences.getInstance();
    _placaCtrl.text = preferencias.getString(_chavePlaca) ?? '';
    try {
      final linhas = await ServicoApi.linhasDisponiveis();
      if (mounted) setState(() => _linhas = linhas);
    } catch (_) {} // sem a lista, o motorista digita a linha
  }

  Future<void> _iniciar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _iniciando = true);
    try {
      final erroPermissao = await RastreadorGps.verificarPermissao();
      if (erroPermissao != null) throw erroPermissao;
      final placa = _placaCtrl.text.trim().toUpperCase();
      final viagem = await ServicoApi.iniciarViagem({
        'placa': placa,
        'linha': _linhas.isEmpty ? _linhaCtrl.text.trim() : _linha,
        'kmInicial': double.parse(_kmCtrl.text.trim().replaceAll(',', '.')),
      });
      (await SharedPreferences.getInstance()).setString(_chavePlaca, placa);
      widget.aoIniciar(viagem);
    } catch (e) {
      // Já existe viagem aberta deste motorista: retoma em vez de travar
      final aberta = (e is ErroApi && e.status == 409) ? await ServicoApi.viagemAtual().catchError((_) => null) : null;
      if (aberta != null) {
        widget.aoIniciar(aberta);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ErroApi ? e.mensagem : (e is String ? e : 'Sem conexão com o servidor')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const espaco = SizedBox(height: 16);
    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Iniciar viagem', style: Theme.of(context).textTheme.titleLarge),
          espaco,
          TextFormField(
            controller: _placaCtrl,
            decoration: const InputDecoration(labelText: 'Placa do ônibus', hintText: 'ABC1D23', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.characters,
            validator: (v) => (v ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length == 7
                ? null
                : 'Placa com 7 letras/números (ex.: ABC1234 ou ABC1D23)',
          ),
          espaco,
          if (_linhas.isEmpty)
            TextFormField(
              controller: _linhaCtrl,
              decoration: const InputDecoration(labelText: 'Linha (ex.: 02)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => RegExp(r'^\d{1,2}$').hasMatch(v?.trim() ?? '') ? null : 'Informe a linha',
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _linha,
              decoration: const InputDecoration(labelText: 'Linha', border: OutlineInputBorder()),
              items: [for (final l in _linhas) DropdownMenuItem(value: l, child: Text('Linha $l'))],
              onChanged: (l) => setState(() => _linha = l),
              validator: (v) => v == null ? 'Escolha a linha' : null,
            ),
          espaco,
          TextFormField(
            controller: _kmCtrl,
            decoration: const InputDecoration(
              labelText: 'Km do hodômetro agora',
              helperText: 'Confira no painel do ônibus',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (double.tryParse((v ?? '').trim().replaceAll(',', '.')) ?? -1) < 0 ? 'Informe o km do hodômetro' : null,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _iniciando ? null : _iniciar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60), backgroundColor: Colors.green),
            icon: const Icon(Icons.gps_fixed, size: 28),
            label: Text(_iniciando ? 'Iniciando...' : 'INICIAR E TRANSMITIR LOCALIZAÇÃO', style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
