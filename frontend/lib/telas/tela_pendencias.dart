import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/importacao.dart';
import '../servicos/servico_api.dart';
import 'tela_revisao.dart';

class TelaPendencias extends StatefulWidget {
  const TelaPendencias({super.key});

  @override
  State<TelaPendencias> createState() => _TelaPendenciasEstado();
}

class _TelaPendenciasEstado extends State<TelaPendencias> {
  List<Importacao> _importacoes = [];
  bool _carregando = true;
  String? _erro;
  String _filtroStatus = '';

  @override
  void initState() {
    super.initState();
    _carregarImportacoes();
  }

  Future<void> _carregarImportacoes() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await ServicoApi.buscarImportacoes(
        status: _filtroStatus.isNotEmpty ? _filtroStatus : null,
      );
      setState(() {
        _importacoes = dados.map((json) => Importacao.deJson(json)).toList();
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Text('Pendências', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(
                onPressed: _carregarImportacoes,
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filtros
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Todas'),
                selected: _filtroStatus == '',
                onSelected: (_) {
                  setState(() => _filtroStatus = '');
                  _carregarImportacoes();
                },
              ),
              FilterChip(
                label: const Text('Pendentes'),
                selected: _filtroStatus == 'pendente',
                selectedColor: Colors.orange.shade100,
                onSelected: (_) {
                  setState(() => _filtroStatus = 'pendente');
                  _carregarImportacoes();
                },
              ),
              FilterChip(
                label: const Text('Confirmadas'),
                selected: _filtroStatus == 'confirmado',
                selectedColor: Colors.green.shade100,
                onSelected: (_) {
                  setState(() => _filtroStatus = 'confirmado');
                  _carregarImportacoes();
                },
              ),
              FilterChip(
                label: const Text('Rejeitadas'),
                selected: _filtroStatus == 'rejeitado',
                selectedColor: Colors.red.shade100,
                onSelected: (_) {
                  setState(() => _filtroStatus = 'rejeitado');
                  _carregarImportacoes();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Conteúdo
          Expanded(
            child: _construirConteudo(),
          ),
        ],
      ),
    );
  }

  Widget _construirConteudo() {
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
            ElevatedButton(onPressed: _carregarImportacoes, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    if (_importacoes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhuma importação encontrada', style: TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _importacoes.length,
      itemBuilder: (context, indice) {
        final importacao = _importacoes[indice];
        final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(importacao.criadoEm);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              importacao.origem == 'email' ? Icons.email : Icons.edit_note,
              color: importacao.origem == 'email' ? Colors.blue : Colors.teal,
              size: 32,
            ),
            title: Text(
              importacao.assunto.isNotEmpty ? importacao.assunto : 'Sem assunto',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('De: ${importacao.remetente}'),
                Text('Data: $dataFormatada'),
              ],
            ),
            trailing: Chip(
              label: Text(
                importacao.status.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: _corDoStatus(importacao.status),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaRevisao(importacaoId: importacao.id),
                ),
              );
              _carregarImportacoes();
            },
          ),
        );
      },
    );
  }
}
