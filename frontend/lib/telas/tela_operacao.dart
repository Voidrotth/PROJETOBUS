import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../componentes/grafico_diario.dart';
import '../servicos/servico_api.dart';

const _tiposDia = {
  'util': 'Dias úteis',
  'nao_util': 'Dias não úteis',
  'feriado': 'Feriados',
};
const _turnos = {'manha': 'Manhã', 'tarde': 'Tarde', 'noite': 'Noite'};
const _tiposNaoCumprida = {
  'nao_realizada': 'Não realizada',
  'nao_iniciada': 'Não iniciada',
  'nao_terminada': 'Não terminada',
};

final _inteiro = NumberFormat('#,##0', 'pt_BR');
final _decimal = NumberFormat('#,##0.0', 'pt_BR');
final _porcento = NumberFormat('0.00', 'pt_BR');

String _dataBr(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

String _iso(DateTime data) =>
    '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

/// Horário da operação (São Paulo, UTC−3) a partir do ISO em UTC que vem da API
String _hora(dynamic iso) =>
    iso == null ? '—' : DateFormat('HH:mm').format(DateTime.parse(iso).toUtc().subtract(const Duration(hours: 3)));

String _num(dynamic valor, [NumberFormat? formato]) => valor == null ? '—' : (formato ?? _inteiro).format(valor);

List<Map<String, dynamic>> _lista(dynamic valor) => ((valor ?? []) as List).cast<Map<String, dynamic>>();

/// Operação a partir das viagens uma a uma (relatório "Viagens" e viagens não cumpridas do Smart Report):
/// cumprimento, linhas, horários, frota e pesquisa de viagens.
class TelaOperacao extends StatefulWidget {
  const TelaOperacao({super.key});

  @override
  State<TelaOperacao> createState() => _TelaOperacaoEstado();
}

class _TelaOperacaoEstado extends State<TelaOperacao> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  String? _erro;

  DateTimeRange? _periodo;
  Set<String> _tipos = {..._tiposDia.keys};
  String? _linha;

  // Pesquisa de viagens
  final _prefixoCtrl = TextEditingController();
  String? _sentido;
  int? _horaPesquisa;
  Map<String, dynamic>? _pesquisa;
  bool _pesquisando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _prefixoCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _filtros() => {
        if (_periodo != null) 'inicio': _iso(_periodo!.start),
        if (_periodo != null) 'fim': _iso(_periodo!.end),
        'tipos': _tipos.join(','),
        'linha': ?_linha,
      };

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _pesquisa = null;
    });
    try {
      final dados = await ServicoApi.buscarOperacao(_filtros());
      if (mounted) setState(() => _dados = dados);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _pesquisar([int pagina = 1]) async {
    setState(() => _pesquisando = true);
    try {
      final resultado = await ServicoApi.pesquisarViagens({
        ..._filtros(),
        if (_prefixoCtrl.text.trim().isNotEmpty) 'prefixo': _prefixoCtrl.text.trim(),
        'sentido': ?_sentido,
        if (_horaPesquisa != null) 'hora': '$_horaPesquisa',
        'pagina': '$pagina',
      });
      if (mounted) setState(() => _pesquisa = resultado);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _pesquisando = false);
    }
  }

  Future<void> _escolherPeriodo(Map<String, dynamic> cobertura) async {
    final inicio = DateTime.parse(cobertura['inicio']);
    final fim = DateTime.parse(cobertura['fim']);
    final escolhido = await showDateRangePicker(
      context: context,
      firstDate: inicio,
      lastDate: fim,
      initialDateRange: _periodo ?? DateTimeRange(start: inicio, end: fim),
    );
    if (escolhido == null || !mounted) return;
    _periodo = escolhido;
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_dados == null) {
      if (_carregando) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_erro ?? 'Erro ao carregar', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    final dados = _dados!;
    final cobertura = Map<String, dynamic>.from(dados['cobertura']);
    if (cobertura['inicio'] == null) {
      return const Center(
        child: Text('Nenhum relatório de operação enviado ainda.\nUse a aba "Enviar dados".', textAlign: TextAlign.center),
      );
    }
    final resumo = Map<String, dynamic>.from(dados['resumo']);
    return Opacity(
      opacity: _carregando ? 0.5 : 1,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _cabecalho(dados, cobertura),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_erro!, style: const TextStyle(color: Colors.red)),
            ),
          if (resumo['dias'] == 0)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhum dia nos filtros escolhidos.')))
          else ...[
            _secaoResumo(resumo),
            if (dados['turnos'] != null) _secaoTurnos(_lista(dados['turnos'])),
            _secaoLinhas(_lista(dados['porLinha']), resumo, Map<String, dynamic>.from(dados['naoCumpridas'])),
            _secaoHoras(_lista(dados['porHora']), _lista(dados['porLinhaHora']), resumo['dias'] as int),
            _secaoFrota(_lista(dados['frota'])),
            _secaoNaoCumpridas(Map<String, dynamic>.from(dados['naoCumpridas'])),
            _secaoPesquisa(),
          ],
        ],
      ),
    );
  }

  // ==================== FILTROS ====================

  Widget _cabecalho(Map<String, dynamic> dados, Map<String, dynamic> cobertura) {
    final periodo = _periodo == null
        ? '${_dataBr(cobertura['inicio'])} a ${_dataBr(cobertura['fim'])} (tudo)'
        : '${_dataBr(_iso(_periodo!.start))} a ${_dataBr(_iso(_periodo!.end))}';
    final linhas = ((dados['linhas'] ?? []) as List).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operação', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Viagens uma a uma, por linha, horário e veículo (relatórios "Viagens" e viagens não cumpridas).',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _escolherPeriodo(cobertura),
                icon: const Icon(Icons.date_range),
                label: Text(periodo),
              ),
              if (_periodo != null)
                TextButton(
                  onPressed: () {
                    _periodo = null;
                    _carregar();
                  },
                  child: const Text('Todo o período'),
                ),
              for (final tipo in _tiposDia.entries)
                FilterChip(
                  label: Text(tipo.value),
                  selected: _tipos.contains(tipo.key),
                  onSelected: (marcado) {
                    final novos = {..._tipos};
                    marcado ? novos.add(tipo.key) : novos.remove(tipo.key);
                    if (novos.isEmpty) return;
                    _tipos = novos;
                    _carregar();
                  },
                ),
              DropdownButton<String?>(
                value: _linha,
                hint: const Text('Todas as linhas'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas as linhas')),
                  for (final linha in linhas) DropdownMenuItem(value: linha, child: Text('Linha $linha')),
                ],
                onChanged: (linha) {
                  _linha = linha;
                  _carregar();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== BLOCOS ====================

  Widget _secao(String titulo, List<Widget> filhos) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...filhos,
            ],
          ),
        ),
      );

  Widget _nota(String texto) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      );

  Widget _indicadores(List<(String, String)> itens) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            for (final (rotulo, valor) in itens)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rotulo, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ],
              ),
          ],
        ),
      );

  Widget _tabela(List<String> colunas, List<List<String>> linhas) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 32,
          columnSpacing: 24,
          columns: [
            for (final coluna in colunas) DataColumn(label: Text(coluna, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: [
            for (final linha in linhas) DataRow(cells: [for (final celula in linha) DataCell(Text(celula))]),
          ],
        ),
      );

  // ==================== RESUMO E TURNOS ====================

  Widget _secaoResumo(Map<String, dynamic> r) => _secao(_linha == null ? 'Resumo do período' : 'Resumo da linha $_linha', [
        _indicadores([
          ('Dias', _num(r['dias'])),
          ('Viagens programadas', _num(r['viagensProgramadas'])),
          ('Viagens realizadas', _num(r['viagensRealizadas'])),
          ('Cumprimento', r['cumprimento'] == null ? '—' : '${_porcento.format(r['cumprimento'])}%'),
          ('Não cumpridas', _num(r['viagensNaoCumpridas'])),
          ('Km produtiva', _num(r['kmProdutiva'], _decimal)),
          ('Km improdutiva', _num(r['kmImprodutiva'], _decimal)),
          ('Km total', _num(r['kmTotal'], _decimal)),
          ('Frota média/dia', _num(r['frotaMedia'], _decimal)),
          ('Frota máxima/dia', _num(r['frotaMaxima'])),
          ('Veículos diferentes', _num(r['veiculosDistintos'])),
        ]),
        if (_linha != null)
          _nota('Viagens programadas, km improdutiva e frota só existem para o sistema inteiro nos relatórios, não por linha.'),
      ]);

  Widget _secaoTurnos(List<Map<String, dynamic>> turnos) => _secao('Cumprimento por turno', [
        _tabela(
          ['Turno', 'Programadas', 'Realizadas', 'Não cumpridas', 'Cumprimento'],
          [
            for (final t in turnos)
              [
                _turnos[t['turno']] ?? t['turno'],
                _num(t['programadas']),
                _num(t['realizadas']),
                _num((t['programadas'] as num) - (t['realizadas'] as num)),
                (t['programadas'] as num) == 0
                    ? '—'
                    : '${_porcento.format((t['realizadas'] as num) / (t['programadas'] as num) * 100)}%',
              ],
          ],
        ),
        _nota('Fonte: Fator de Cumprimento de Viagem. Os horários de início e fim de cada turno não vêm no relatório.'),
      ]);

  // ==================== LINHAS ====================

  Widget _secaoLinhas(List<Map<String, dynamic>> porLinha, Map<String, dynamic> resumo, Map<String, dynamic> naoCumpridas) {
    final totalViagens = porLinha.fold<num>(0, (s, l) => s + (l['viagens'] as num));
    final ncPorLinha = {for (final x in _lista(naoCumpridas['porLinha'])) x['linha']: x['quantidade']};
    final dias = resumo['dias'] as int;
    return _secao('Por linha', [
      GraficoDiario(
        rotulos: [for (final l in porLinha) l['linha'] as String],
        series: [SerieGrafico('Viagens realizadas', corSerie1, [for (final l in porLinha) (l['viagens'] as num).toDouble()])],
        formatar: (v) => _inteiro.format(v),
      ),
      const SizedBox(height: 12),
      _tabela(
        ['Linha', 'Viagens', 'Viagens/dia', '% das viagens', 'Km produtiva', 'Veículos', 'Não cumpridas'],
        [
          for (final l in porLinha)
            [
              l['linha'],
              _num(l['viagens']),
              _num((l['viagens'] as num) / (l['dias'] as num), _decimal),
              totalViagens == 0 ? '—' : '${_porcento.format((l['viagens'] as num) / totalViagens * 100)}%',
              _num(l['kmProdutiva'], _decimal),
              _num(l['veiculos']),
              _num(ncPorLinha[l['linha']] ?? 0),
            ],
        ],
      ),
      _nota('$dias dia(s) no filtro. Veículos = prefixos diferentes que fizeram ao menos uma viagem na linha.'),
    ]);
  }

  // ==================== HORÁRIOS ====================

  Widget _secaoHoras(List<Map<String, dynamic>> porHora, List<Map<String, dynamic>> porLinhaHora, int dias) {
    final linhas = {for (final x in porLinhaHora) x['linha'] as String}.toList()..sort();
    final horas = [for (final h in porHora) h['hora'] as int];
    final celula = {for (final x in porLinhaHora) '${x['linha']}|${x['hora']}': (x['viagens'] as num) / dias};
    final maior = celula.values.fold<double>(0, (m, v) => v > m ? v.toDouble() : m);
    return _secao('Por horário de partida', [
      GraficoDiario(
        rotulos: [for (final h in horas) '${h}h'],
        series: [
          SerieGrafico('Viagens por dia (média)', corSerie1, [for (final h in porHora) (h['viagens'] as num) / dias]),
          SerieGrafico('Veículos na hora (média)', corSerie2, [for (final h in porHora) (h['veiculosMedia'] as num).toDouble()]),
        ],
        formatar: (v) => _decimal.format(v),
      ),
      const SizedBox(height: 16),
      Text('Viagens por dia, linha × hora', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      // Mapa de calor: a intensidade da cor acompanha o número (que também está escrito na célula)
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(40),
          columnWidths: const {0: FixedColumnWidth(56)},
          children: [
            TableRow(children: [
              const SizedBox(),
              for (final h in horas)
                Padding(padding: const EdgeInsets.all(4), child: Text('${h}h', style: const TextStyle(fontSize: 11))),
            ]),
            for (final linha in linhas)
              TableRow(children: [
                Padding(padding: const EdgeInsets.all(4), child: Text('Linha $linha', style: const TextStyle(fontSize: 11))),
                for (final h in horas)
                  () {
                    final valor = celula['$linha|$h'] ?? 0;
                    return Container(
                      height: 26,
                      margin: const EdgeInsets.all(1),
                      alignment: Alignment.center,
                      color: corSerie1.withValues(alpha: maior == 0 ? 0 : 0.08 + 0.85 * valor / maior),
                      child: Text(
                        valor == 0 ? '' : _decimal.format(valor),
                        style: TextStyle(fontSize: 10, color: valor / (maior == 0 ? 1 : maior) > 0.55 ? Colors.white : Colors.black87),
                      ),
                    );
                  }(),
              ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _tabela(
        ['Hora', 'Viagens', 'Viagens/dia', 'Veículos (média)', 'Veículos (máximo)'],
        [
          for (final h in porHora)
            [
              '${h['hora']}h',
              _num(h['viagens']),
              _num((h['viagens'] as num) / dias, _decimal),
              _num(h['veiculosMedia'], _decimal),
              _num(h['veiculosMax']),
            ],
        ],
      ),
      _nota('Hora = hora de início da viagem. Viagens depois da meia-noite contam no dia operacional anterior.'),
    ]);
  }

  // ==================== FROTA ====================

  Widget _secaoFrota(List<Map<String, dynamic>> frota) {
    final ordenada = [...frota]..sort((a, b) => (b['kmProdutiva'] as num).compareTo(a['kmProdutiva'] as num));
    return _secao('Frota (por veículo)', [
      _tabela(
        ['Prefixo', 'Dias', 'Viagens', 'Km produtiva', 'Km improdutiva', 'Km/dia', 'Linhas'],
        [
          for (final v in ordenada)
            [
              v['prefixo'],
              _num(v['dias']),
              _num(v['viagens']),
              _num(v['kmProdutiva'], _decimal),
              _num(_linha == null ? v['kmImprodutiva'] : null, _decimal),
              _num(((v['kmProdutiva'] as num) + (_linha == null ? v['kmImprodutiva'] as num : 0)) / (v['dias'] as num), _decimal),
              ((v['linhas'] ?? []) as List).join(', '),
            ],
        ],
      ),
      _nota('Km improdutiva = deslocamento sem passageiros (garagem ↔ linha), informado por veículo e dia, sem linha.'),
    ]);
  }

  // ==================== NÃO CUMPRIDAS ====================

  Widget _secaoNaoCumpridas(Map<String, dynamic> nc) {
    final lista = _lista(nc['lista']);
    return _secao('Viagens não cumpridas', [
      _indicadores([
        ('Total', _num(lista.length)),
        for (final t in _lista(nc['porTipo'])) (_tiposNaoCumprida[t['tipo']] ?? t['tipo'] as String, _num(t['quantidade'])),
      ]),
      if (lista.isEmpty)
        const Text('Nenhuma viagem não cumprida nos filtros escolhidos.')
      else ...[
        _tabela(
          ['Tipo', 'Data', 'Linha', 'Atendimento', 'Sentido', 'Tabela', 'Motorista', 'Prefixo', 'Programado', 'Realizado', 'Status'],
          [
            for (final x in lista)
              [
                _tiposNaoCumprida[x['tipo']] ?? x['tipo'],
                _dataBr(x['data']),
                x['linha'],
                x['atendimento'],
                x['sentido'] == 'ida' ? 'Ida' : 'Volta',
                x['tabela'],
                x['motorista'],
                x['prefixo'] ?? '—',
                '${_hora(x['inicioProgramado'])}–${_hora(x['fimProgramado'])}',
                '${_hora(x['inicioRealizado'])}–${_hora(x['fimRealizado'])}',
                [x['statusSaida'], x['statusChegada']].where((s) => s != null).join(' / '),
              ],
          ],
        ),
        const SizedBox(height: 16),
        Text('Motoristas com mais viagens não cumpridas', style: Theme.of(context).textTheme.titleMedium),
        _tabela(
          ['Motorista (matrícula)', 'Viagens'],
          [
            for (final m in _lista(nc['porMotorista']).take(10)) [m['motorista'] as String, _num(m['quantidade'])],
          ],
        ),
        _nota('Os relatórios não explicam os códigos de status (RG, AD, AT) nem trazem o nome do motorista: aparecem como vieram.'),
      ],
    ]);
  }

  // ==================== PESQUISA DE VIAGENS ====================

  Widget _secaoPesquisa() {
    final viagens = _lista(_pesquisa?['viagens']);
    final total = _pesquisa?['total'] as int? ?? 0;
    final pagina = _pesquisa?['pagina'] as int? ?? 1;
    final porPagina = _pesquisa?['porPagina'] as int? ?? 200;
    return _secao('Pesquisar viagens', [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: TextField(
              controller: _prefixoCtrl,
              decoration: const InputDecoration(labelText: 'Prefixo (ônibus)', isDense: true),
              onSubmitted: (_) => _pesquisar(),
            ),
          ),
          DropdownButton<String?>(
            value: _sentido,
            hint: const Text('Sentido'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ida e volta')),
              DropdownMenuItem(value: 'ida', child: Text('Ida')),
              DropdownMenuItem(value: 'volta', child: Text('Volta')),
            ],
            onChanged: (valor) => setState(() => _sentido = valor),
          ),
          DropdownButton<int?>(
            value: _horaPesquisa,
            hint: const Text('Hora'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Qualquer hora')),
              for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('${h}h')),
            ],
            onChanged: (valor) => setState(() => _horaPesquisa = valor),
          ),
          FilledButton.icon(
            onPressed: _pesquisando ? null : () => _pesquisar(),
            icon: const Icon(Icons.search),
            label: const Text('Pesquisar'),
          ),
        ],
      ),
      _nota('Usa também o período, os tipos de dia e a linha escolhidos no topo.'),
      if (_pesquisando) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      if (_pesquisa != null) ...[
        const SizedBox(height: 12),
        Text(total == 0
            ? 'Nenhuma viagem encontrada.'
            : '${_inteiro.format(total)} registro(s) · mostrando ${(pagina - 1) * porPagina + 1}–${(pagina - 1) * porPagina + viagens.length}'),
        if (viagens.isNotEmpty)
          _tabela(
            ['Data', 'Linha', 'Prefixo', 'Atividade', 'Sentido', 'Início', 'Fim', 'Km produtiva', 'Km improdutiva'],
            [
              for (final v in viagens)
                [
                  _dataBr(v['data']),
                  v['linha'] ?? '—',
                  v['prefixo'],
                  v['atividade'] == 'normal' ? 'Viagem' : 'Improdutiva',
                  v['sentido'] == null ? '—' : (v['sentido'] == 'ida' ? 'Ida' : 'Volta'),
                  _hora(v['inicio']),
                  _hora(v['fim']),
                  _num(v['kmProdutiva'], _decimal),
                  _num(v['kmImprodutiva'], _decimal),
                ],
            ],
          ),
        if (total > porPagina)
          Row(
            children: [
              TextButton(onPressed: pagina > 1 && !_pesquisando ? () => _pesquisar(pagina - 1) : null, child: const Text('Anterior')),
              Text('Página $pagina de ${(total / porPagina).ceil()}'),
              TextButton(
                onPressed: pagina * porPagina < total && !_pesquisando ? () => _pesquisar(pagina + 1) : null,
                child: const Text('Próxima'),
              ),
            ],
          ),
      ],
    ]);
  }
}
