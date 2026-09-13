import 'package:flutter/material.dart';
import '../servicos/servico_api.dart';

class TelaPainel extends StatefulWidget {
  const TelaPainel({super.key});

  @override
  State<TelaPainel> createState() => _TelaPainelEstado();
}

class _TelaPainelEstado extends State<TelaPainel> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await ServicoApi.buscarPainel();
      setState(() {
        _dados = dados;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar painel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_erro!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _carregarDados,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final dados = _dados!;

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Text('Painel', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                IconButton(
                  onPressed: _carregarDados,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cartões de resumo
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _construirCartao('Total de Operações', '${dados['totalOperacoes'] ?? 0}',
                    Icons.directions_bus, Colors.blue),
                _construirCartao('Passageiros', '${dados['totalPassageiros'] ?? 0}',
                    Icons.people, Colors.green),
                _construirCartao('Viagens', '${dados['totalViagens'] ?? 0}',
                    Icons.route, Colors.orange),
                _construirCartao('Km Rodados', '${dados['totalKm'] ?? 0}',
                    Icons.speed, Colors.purple),
              ],
            ),
            const SizedBox(height: 32),

            // Operações por linha
            Text('Operações por Linha', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _construirTabelaLinhas(dados['operacoesPorLinha'] ?? []),
            const SizedBox(height: 32),

            // Últimas ocorrências
            Text('Últimas Ocorrências', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _construirListaOcorrencias(dados['ultimasOcorrencias'] ?? []),
          ],
        ),
      ),
    );
  }

  Widget _construirCartao(String titulo, String valor, IconData icone, Color cor) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 36, color: cor),
              const SizedBox(height: 12),
              Text(valor,
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: cor)),
              const SizedBox(height: 4),
              Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirTabelaLinhas(List<dynamic> linhas) {
    if (linhas.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma operação registrada'),
        ),
      );
    }

    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Linha', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Operações', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: linhas.map<DataRow>((item) {
          return DataRow(cells: [
            DataCell(Text(item['_id'] ?? 'N/A')),
            DataCell(Text('${item['total']}')),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _construirListaOcorrencias(List<dynamic> ocorrencias) {
    if (ocorrencias.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma ocorrência registrada'),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ocorrencias.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, indice) {
          final item = ocorrencias[indice];
          return ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            title: Text('Linha ${item['linha'] ?? 'N/A'} - Veículo ${item['veiculo'] ?? 'N/A'}'),
            subtitle: Text(item['ocorrencias'] ?? ''),
          );
        },
      ),
    );
  }
}
