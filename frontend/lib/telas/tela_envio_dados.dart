import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../servicos/arquivos_navegador.dart';
import '../servicos/servico_api.dart';

const _usos = {
  'indicadores': ('Usado no painel', Icons.check_circle, Color(0xFF0CA30C)),
  'conferencia': ('Usado na conferência (os números saem das viagens)', Icons.fact_check, Color(0xFF0CA30C)),
  'nao_utilizado': ('Não reconhecido', Icons.remove_circle_outline, Colors.black54),
  'duplicado': ('Já tinha sido enviado', Icons.copy, Colors.black54),
  'erro': ('Recusado', Icons.error, Color(0xFFD03B3B)),
};

/// Envio dos dados que alimentam o painel de verificação:
/// relatórios do Smart Report em HTML e planilhas CSV com o que eles não trazem.
class TelaEnvioDados extends StatefulWidget {
  const TelaEnvioDados({super.key});

  @override
  State<TelaEnvioDados> createState() => _TelaEnvioDadosEstado();
}

class _TelaEnvioDadosEstado extends State<TelaEnvioDados> {
  final List<(String, Uint8List)> _escolhidos = [];
  Map<String, dynamic>? _importacao;
  String? _andamento;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarUltima();
  }

  Future<void> _carregarUltima() async {
    try {
      final importacao = await ServicoApi.ultimaImportacaoDados();
      if (mounted) setState(() => _importacao = importacao);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  Future<void> _escolher() async {
    try {
      final arquivos = await escolherArquivos('.html,.htm,.csv');
      if (mounted) setState(() => _escolhidos.addAll(arquivos));
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  Future<void> _enviar() async {
    final agora = DateTime.now();
    String dois(int n) => n.toString().padLeft(2, '0');
    final envio = '${agora.year}${dois(agora.month)}${dois(agora.day)}-${dois(agora.hour)}${dois(agora.minute)}${dois(agora.second)}';
    try {
      for (var i = 0; i < _escolhidos.length; i++) {
        final (nome, bytes) = _escolhidos[i];
        setState(() {
          _erro = null;
          _andamento = 'Enviando ${i + 1} de ${_escolhidos.length}: $nome';
        });
        await ServicoApi.enviarArquivo(envio, nome, bytes);
      }
      setState(() => _andamento = 'Lendo os arquivos e atualizando o painel…');
      final resultado = await ServicoApi.processarDados();
      if (!mounted) return;
      setState(() {
        _importacao = resultado;
        _escolhidos.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _andamento = null);
    }
  }

  void _baixarModelo() {
    try {
      baixarArquivo(
        'modelo_receita_catraca.csv',
        'text/csv',
        utf8.encode('﻿data;receitaCatracaDinheiro;receitaCatracaCartao\r\n01/10/2026;0,00;0,00\r\n'),
      );
    } catch (e) {
      setState(() => _erro = e.toString());
    }
  }

  String _tamanho(int bytes) =>
      bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

  @override
  Widget build(BuildContext context) {
    final enviando = _andamento != null;
    final arquivos = ((_importacao?['arquivos'] ?? []) as List).cast<Map<String, dynamic>>();
    final conferencias = ((_importacao?['conferencias'] ?? []) as List).cast<Map<String, dynamic>>();
    final comDivergencia = conferencias.where((c) => (c['divergencias'] as List).isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Enviar dados', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Mande aqui os arquivos do verificador. O painel de Verificação é refeito com tudo que já foi enviado.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Formatos aceitos', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('• HTML do Smart Report: os 11 relatórios (Resumo Geral, FCV, Linhas, Faixa Horária, Resumo Faixa Horária, Viagens, '
                    'viagens não realizadas/iniciadas/terminadas, Passageiros e Saldos). Pode mandar todos de uma vez: cada um é '
                    'reconhecido pelas colunas; se o layout mudar, a IA identifica as colunas e o sistema confere antes de gravar.'),
                const Text('• Planilha CSV, para o que os relatórios não trazem (ex.: receita de catraca em dinheiro e em cartão). '
                    'Primeira coluna "data"; as outras com o nome do campo.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: enviando ? null : _escolher,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Escolher arquivos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _baixarModelo,
                      icon: const Icon(Icons.table_view),
                      label: const Text('Baixar modelo de CSV'),
                    ),
                  ],
                ),
                if (_escolhidos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final (nome, bytes) in _escolhidos)
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(nome)),
                        Text(_tamanho(bytes.length), style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: enviando ? null : _enviar,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text('Enviar ${_escolhidos.length} arquivo(s) e atualizar o painel'),
                      ),
                      TextButton(
                        onPressed: enviando ? null : () => setState(_escolhidos.clear),
                        child: const Text('Limpar lista'),
                      ),
                    ],
                  ),
                ],
                if (enviando) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  Text(_andamento!),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error, color: Color(0xFFD03B3B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_erro!)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_importacao == null)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Nenhum arquivo foi lido ainda.')))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Última leitura: ${arquivos.length} arquivos', style: Theme.of(context).textTheme.titleLarge),
                  Text(comDivergencia == 0
                      ? 'As ${conferencias.length} conferências fecharam sem divergência.'
                      : '$comDivergencia de ${conferencias.length} conferências têm pontos de atenção (detalhes na aba Verificação).'),
                  const SizedBox(height: 12),
                  for (final arquivo in arquivos)
                    () {
                      final (rotulo, icone, cor) = _usos[arquivo['uso']] ?? ('', Icons.help_outline, Colors.black54);
                      final relatorios = ((arquivo['relatorios'] ?? []) as List).join(' + ');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icone, size: 18, color: cor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${arquivo['arquivo']}\n'
                                  '$rotulo${arquivo['erro'] != null ? ': ${arquivo['erro']}' : ''}'
                                  '${relatorios.isEmpty ? '' : ' · $relatorios'}'
                                  '${(arquivo['identificacao'] ?? '').toString().split(', ').contains('ia') ? ' · colunas identificadas pela IA' : ''}'
                                  '${arquivo['inicio'] != null ? ' · ${arquivo['inicio']} a ${arquivo['fim']}' : ''}'),
                            ),
                          ],
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
