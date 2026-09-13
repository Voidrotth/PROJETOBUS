import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servicos/servico_api.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroEstado();
}

class _TelaCadastroEstado extends State<TelaCadastro> {
  final _chaveFormulario = GlobalKey<FormState>();
  bool _salvando = false;

  // Controladores dos campos
  final _linhaCtrl = TextEditingController();
  final _veiculoCtrl = TextEditingController();
  final _motoristaCtrl = TextEditingController();
  final _cobradorCtrl = TextEditingController();
  final _horarioSaidaCtrl = TextEditingController();
  final _horarioRecolhimentoCtrl = TextEditingController();
  final _kmInicialCtrl = TextEditingController();
  final _kmFinalCtrl = TextEditingController();
  final _passageirosCtrl = TextEditingController();
  final _viagensCtrl = TextEditingController();
  final _ocorrenciasCtrl = TextEditingController();

  DateTime? _dataOperacao;

  @override
  void dispose() {
    _linhaCtrl.dispose();
    _veiculoCtrl.dispose();
    _motoristaCtrl.dispose();
    _cobradorCtrl.dispose();
    _horarioSaidaCtrl.dispose();
    _horarioRecolhimentoCtrl.dispose();
    _kmInicialCtrl.dispose();
    _kmFinalCtrl.dispose();
    _passageirosCtrl.dispose();
    _viagensCtrl.dispose();
    _ocorrenciasCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataOperacao ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() => _dataOperacao = data);
    }
  }

  Future<void> _salvar() async {
    if (!_chaveFormulario.currentState!.validate()) return;
    if (_dataOperacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data da operação'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      await ServicoApi.criarOperacao({
        'linha': _linhaCtrl.text,
        'veiculo': _veiculoCtrl.text,
        'motorista': _motoristaCtrl.text,
        'cobrador': _cobradorCtrl.text,
        'dataOperacao': _dataOperacao!.toIso8601String(),
        'horarioSaida': _horarioSaidaCtrl.text,
        'horarioRecolhimento': _horarioRecolhimentoCtrl.text,
        'kmInicial': double.tryParse(_kmInicialCtrl.text) ?? 0,
        'kmFinal': double.tryParse(_kmFinalCtrl.text) ?? 0,
        'passageiros': int.tryParse(_passageirosCtrl.text) ?? 0,
        'viagens': int.tryParse(_viagensCtrl.text) ?? 0,
        'ocorrencias': _ocorrenciasCtrl.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operação cadastrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _limparFormulario();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _limparFormulario() {
    _chaveFormulario.currentState?.reset();
    _linhaCtrl.clear();
    _veiculoCtrl.clear();
    _motoristaCtrl.clear();
    _cobradorCtrl.clear();
    _horarioSaidaCtrl.clear();
    _horarioRecolhimentoCtrl.clear();
    _kmInicialCtrl.clear();
    _kmFinalCtrl.clear();
    _passageirosCtrl.clear();
    _viagensCtrl.clear();
    _ocorrenciasCtrl.clear();
    setState(() => _dataOperacao = null);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _chaveFormulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Cadastro Manual', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Preencha os dados da operação. Campos com * são obrigatórios.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                // Linha *
                TextFormField(
                  controller: _linhaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Linha *',
                    hintText: 'Ex: 1234 - Circular Centro',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.route),
                  ),
                  validator: (valor) => valor == null || valor.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                // Veículo *
                TextFormField(
                  controller: _veiculoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Veículo *',
                    hintText: 'Ex: ABC-1D23',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_bus),
                  ),
                  validator: (valor) => valor == null || valor.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                // Motorista *
                TextFormField(
                  controller: _motoristaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motorista *',
                    hintText: 'Nome do motorista',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (valor) => valor == null || valor.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                // Cobrador
                TextFormField(
                  controller: _cobradorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cobrador',
                    hintText: 'Nome do cobrador (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),

                // Data da operação *
                InkWell(
                  onTap: _selecionarData,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data da Operação *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _dataOperacao != null
                          ? DateFormat('dd/MM/yyyy').format(_dataOperacao!)
                          : 'Selecione a data',
                      style: TextStyle(
                        color: _dataOperacao != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Horários
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _horarioSaidaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Horário de Saída',
                          hintText: 'HH:MM',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _horarioRecolhimentoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Horário Recolhimento',
                          hintText: 'HH:MM',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Km
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kmInicialCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Km Inicial',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.speed),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _kmFinalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Km Final',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.speed),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Passageiros e viagens
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passageirosCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Passageiros',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _viagensCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Viagens',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.repeat),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ocorrências
                TextFormField(
                  controller: _ocorrenciasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ocorrências',
                    hintText: 'Descreva qualquer ocorrência durante a operação',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning_amber),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Botão salvar
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_salvando ? 'Salvando...' : 'Cadastrar Operação'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
