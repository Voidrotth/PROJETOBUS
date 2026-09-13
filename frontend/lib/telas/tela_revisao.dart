import 'package:flutter/material.dart';
import '../modelos/importacao.dart';
import '../servicos/servico_api.dart';

class TelaRevisao extends StatefulWidget {
  final String importacaoId;

  const TelaRevisao({super.key, required this.importacaoId});

  @override
  State<TelaRevisao> createState() => _TelaRevisaoEstado();
}

class _TelaRevisaoEstado extends State<TelaRevisao> {
  Importacao? _importacao;
  bool _carregando = true;
  bool _processando = false;
  String? _erro;

  // Controladores dos campos editáveis
  final _linhaCtrl = TextEditingController();
  final _veiculoCtrl = TextEditingController();
  final _motoristaCtrl = TextEditingController();
  final _cobradorCtrl = TextEditingController();
  final _dataOperacaoCtrl = TextEditingController();
  final _horarioSaidaCtrl = TextEditingController();
  final _horarioRecolhimentoCtrl = TextEditingController();
  final _kmInicialCtrl = TextEditingController();
  final _kmFinalCtrl = TextEditingController();
  final _passageirosCtrl = TextEditingController();
  final _viagensCtrl = TextEditingController();
  final _ocorrenciasCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarImportacao();
  }

  @override
  void dispose() {
    _linhaCtrl.dispose();
    _veiculoCtrl.dispose();
    _motoristaCtrl.dispose();
    _cobradorCtrl.dispose();
    _dataOperacaoCtrl.dispose();
    _horarioSaidaCtrl.dispose();
    _horarioRecolhimentoCtrl.dispose();
    _kmInicialCtrl.dispose();
    _kmFinalCtrl.dispose();
    _passageirosCtrl.dispose();
    _viagensCtrl.dispose();
    _ocorrenciasCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarImportacao() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await ServicoApi.buscarImportacao(widget.importacaoId);
      final importacao = Importacao.deJson(dados);
      setState(() {
        _importacao = importacao;
        _carregando = false;
      });
      _preencherCampos(importacao.dadosExtraidos);
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  void _preencherCampos(Map<String, dynamic> dados) {
    _linhaCtrl.text = dados['linha']?.toString() ?? '';
    _veiculoCtrl.text = dados['veiculo']?.toString() ?? '';
    _motoristaCtrl.text = dados['motorista']?.toString() ?? '';
    _cobradorCtrl.text = dados['cobrador']?.toString() ?? '';
    _dataOperacaoCtrl.text = dados['dataOperacao']?.toString() ?? '';
    _horarioSaidaCtrl.text = dados['horarioSaida']?.toString() ?? '';
    _horarioRecolhimentoCtrl.text = dados['horarioRecolhimento']?.toString() ?? '';
    _kmInicialCtrl.text = dados['kmInicial']?.toString() ?? '';
    _kmFinalCtrl.text = dados['kmFinal']?.toString() ?? '';
    _passageirosCtrl.text = dados['passageiros']?.toString() ?? '';
    _viagensCtrl.text = dados['viagens']?.toString() ?? '';
    _ocorrenciasCtrl.text = dados['ocorrencias']?.toString() ?? '';
  }

  Map<String, dynamic> _coletarDados() {
    return {
      'linha': _linhaCtrl.text,
      'veiculo': _veiculoCtrl.text,
      'motorista': _motoristaCtrl.text,
      'cobrador': _cobradorCtrl.text,
      'dataOperacao': _dataOperacaoCtrl.text,
      'horarioSaida': _horarioSaidaCtrl.text,
      'horarioRecolhimento': _horarioRecolhimentoCtrl.text,
      'kmInicial': double.tryParse(_kmInicialCtrl.text) ?? 0,
      'kmFinal': double.tryParse(_kmFinalCtrl.text) ?? 0,
      'passageiros': int.tryParse(_passageirosCtrl.text) ?? 0,
      'viagens': int.tryParse(_viagensCtrl.text) ?? 0,
      'ocorrencias': _ocorrenciasCtrl.text,
    };
  }

  Future<void> _salvarAlteracoes() async {
    setState(() => _processando = true);
    try {
      await ServicoApi.atualizarImportacao(widget.importacaoId, _coletarDados());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alterações salvas'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _confirmar() async {
    // Campos obrigatórios da operação
    final faltando = <String>[
      if (_linhaCtrl.text.trim().isEmpty) 'Linha',
      if (_veiculoCtrl.text.trim().isEmpty) 'Veículo',
      if (_motoristaCtrl.text.trim().isEmpty) 'Motorista',
    ];
    if (faltando.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preencha antes de confirmar: ${faltando.join(', ')}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _processando = true);
    try {
      await ServicoApi.atualizarImportacao(widget.importacaoId, _coletarDados());
      await ServicoApi.confirmarImportacao(widget.importacaoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importação confirmada!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final mensagem = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _rejeitar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar importação'),
        content: const Text('Tem certeza que deseja rejeitar esta importação? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _processando = true);
    try {
      await ServicoApi.rejeitarImportacao(widget.importacaoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importação rejeitada'), backgroundColor: Colors.orange),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Color _corDoStatus(String status) {
    switch (status) {
      case 'pendente':
        return Colors.orange;
      case 'confirmado':
        return Colors.green;
      case 'rejeitado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisão de Importação'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _construirCorpo(),
    );
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_erro!),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _carregarImportacao, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    final importacao = _importacao!;
    final ehPendente = importacao.status == 'pendente';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status
              Card(
                color: _corDoStatus(importacao.status).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: _corDoStatus(importacao.status)),
                      const SizedBox(width: 12),
                      const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text(importacao.status.toUpperCase(),
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: _corDoStatus(importacao.status),
                      ),
                      const Spacer(),
                      Text('Origem: ${importacao.origem}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Informações do e-mail
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Informações do E-mail',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      _construirLinhaInfo('Remetente', importacao.remetente),
                      _construirLinhaInfo('Assunto', importacao.assunto),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Conteúdo original
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conteúdo Original',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          importacao.conteudoOriginal,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dados extraídos pela IA (editáveis)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dados Extraídos pela IA',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        ehPendente
                            ? 'Revise e corrija os dados antes de confirmar.'
                            : 'Dados somente leitura (importação já processada).',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const Divider(),
                      _construirCampoTexto('Linha', _linhaCtrl, ehPendente),
                      _construirCampoTexto('Veículo', _veiculoCtrl, ehPendente),
                      _construirCampoTexto('Motorista', _motoristaCtrl, ehPendente),
                      _construirCampoTexto('Cobrador', _cobradorCtrl, ehPendente),
                      _construirCampoTexto('Data da Operação (AAAA-MM-DD)', _dataOperacaoCtrl, ehPendente),
                      Row(
                        children: [
                          Expanded(child: _construirCampoTexto('Horário Saída', _horarioSaidaCtrl, ehPendente)),
                          const SizedBox(width: 12),
                          Expanded(child: _construirCampoTexto('Horário Recolhimento', _horarioRecolhimentoCtrl, ehPendente)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _construirCampoTexto('Km Inicial', _kmInicialCtrl, ehPendente)),
                          const SizedBox(width: 12),
                          Expanded(child: _construirCampoTexto('Km Final', _kmFinalCtrl, ehPendente)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _construirCampoTexto('Passageiros', _passageirosCtrl, ehPendente)),
                          const SizedBox(width: 12),
                          Expanded(child: _construirCampoTexto('Viagens', _viagensCtrl, ehPendente)),
                        ],
                      ),
                      _construirCampoTexto('Ocorrências', _ocorrenciasCtrl, ehPendente),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botões de ação (só se pendente)
              if (ehPendente)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _processando ? null : _salvarAlteracoes,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar Alterações'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processando ? null : _confirmar,
                        icon: _processando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle),
                        label: const Text('Confirmar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processando ? null : _rejeitar,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Rejeitar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirLinhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$rotulo:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(valor.isNotEmpty ? valor : 'N/A')),
        ],
      ),
    );
  }

  Widget _construirCampoTexto(String rotulo, TextEditingController controlador, bool editavel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controlador,
        readOnly: !editavel,
        decoration: InputDecoration(
          labelText: rotulo,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: !editavel,
          fillColor: editavel ? null : Colors.grey.shade100,
        ),
      ),
    );
  }
}
