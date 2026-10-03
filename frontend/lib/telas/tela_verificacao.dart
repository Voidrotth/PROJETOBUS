import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../componentes/grafico_diario.dart';
import '../servicos/arquivos_navegador.dart';
import '../servicos/servico_api.dart';

const _tiposDia = {
  'util': 'Dias úteis',
  'nao_util': 'Dias não úteis',
  'feriado': 'Feriados',
};
const _meses = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
const _camposMoeda = {
  'vendas',
  'utilizacao',
  'circulante',
  'circulanteAcumulado',
  'transferidos',
  'saldoFinal',
  'receitaCatracaDinheiro',
  'receitaCatracaCartao',
  'receitaCatraca',
};
const _camposKm = {'kmProdutiva', 'kmImprodutiva', 'kmTotal'};

// Cores de estado (sempre com ícone e texto junto, nunca sozinhas)
const _corNormal = Color(0xFF0CA30C);
const _corAmarelo = Color(0xFFFAB219);
const _corVermelho = Color(0xFFD03B3B);

final _inteiro = NumberFormat('#,##0', 'pt_BR');
final _decimal = NumberFormat('#,##0.0', 'pt_BR');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _moedaSemCentavos = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
final _variacao = NumberFormat('+#,##0.0%;-#,##0.0%', 'pt_BR');

NumberFormat _formatoDe(String campo) =>
    _camposMoeda.contains(campo) ? _moeda : (_camposKm.contains(campo) ? _decimal : _inteiro);

String _valor(dynamic valor, String campo) => valor == null ? '—' : _formatoDe(campo).format(valor);

/// 2026-07-15 -> 15/07/2026
String _dataBr(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

String _iso(DateTime data) =>
    '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

double? _numero(dynamic valor) => (valor as num?)?.toDouble();

double _soma(List<Map<String, dynamic>> dias, String campo) =>
    dias.fold<double>(0, (soma, dia) => soma + ((dia[campo] as num?) ?? 0).toDouble());

List<Map<String, dynamic>> _lista(dynamic valor) => ((valor ?? []) as List).cast<Map<String, dynamic>>();

/// Painel de verificação do relatório mensal: demanda, receita, crédito circulante e quilometragem.
/// Tudo vem dos arquivos enviados na aba "Enviar dados"; o que eles não trazem aparece como sem dado.
class TelaVerificacao extends StatefulWidget {
  const TelaVerificacao({super.key});

  @override
  State<TelaVerificacao> createState() => _TelaVerificacaoEstado();
}

class _TelaVerificacaoEstado extends State<TelaVerificacao> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  String? _erro;

  // Filtros (valem para todos os gráficos, tabelas e exportações).
  // Padrão só dias úteis: é onde aparece o pico de demanda da semana.
  DateTimeRange? _periodo;
  Set<String> _tipos = {'util'};
  bool _demandaEmBarras = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Map<String, String> _filtros() => {
        if (_periodo != null) 'inicio': _iso(_periodo!.start),
        if (_periodo != null) 'fim': _iso(_periodo!.end),
        'tipos': _tipos.join(','),
      };

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await ServicoApi.buscarIndicadores(_filtros());
      if (mounted) setState(() => _dados = dados);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _avisar(Object mensagem) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem.toString())));
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

  Future<void> _exportar(String formato, String escopo) async {
    try {
      final bytes = await ServicoApi.exportarIndicadores({..._filtros(), 'formato': formato, 'escopo': escopo});
      final dias = _lista(_dados!['dias']);
      final nome = escopo == 'quilometragem' ? 'quilometragem' : 'indicadores';
      baixarArquivo(
        '${nome}_${dias.first['data']}_${dias.last['data']}.$formato',
        formato == 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes,
      );
    } catch (e) {
      _avisar(e);
    }
  }

  Future<void> _abrirRelatorioQuilometragem() async {
    try {
      abrirEmNovaAba('text/html', await ServicoApi.relatorioQuilometragem(_filtros()));
    } catch (e) {
      _avisar(e);
    }
  }

  Future<void> _abrirFeriados(Map<String, dynamic> dados) async {
    final mudou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoFeriados(
        feriados: _lista(dados['feriados']),
        sugestoes: _lista(dados['sugestoesFeriado']),
      ),
    );
    if (mudou == true && mounted) _carregar();
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
    if (cobertura['operacao']['inicio'] == null) {
      return const Center(
        child: Text('Nenhum dado enviado ainda.\nUse a aba "Enviar dados" para mandar os relatórios.', textAlign: TextAlign.center),
      );
    }

    final dias = _lista(dados['dias']);
    // Durante a atualização mantém a tela anterior esmaecida, sem pular o layout
    return Opacity(
      opacity: _carregando ? 0.5 : 1,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _cabecalho(dados, cobertura, dias),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_erro!, style: const TextStyle(color: Colors.red)),
            ),
          if (dias.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhum dia nos filtros escolhidos.')))
          else ...[
            _secaoDemanda(dias, Map<String, dynamic>.from(dados['demanda'])),
            _secaoReceita(dias, _lista(dados['meses'])),
            _secaoCirculante(dias, dados['alertaCirculante'], dados['importacao']),
            _secaoQuilometragem(dias),
            _secaoResumo(_lista(dados['meses'])),
            _secaoTabelaDiaria(dias),
          ],
          _secaoCobertura(cobertura, dados['importacao']),
          _secaoConferencia(dados['importacao']),
        ],
      ),
    );
  }

  // ==================== FILTROS E EXPORTAÇÃO ====================

  Widget _cabecalho(Map<String, dynamic> dados, Map<String, dynamic> cobertura, List<Map<String, dynamic>> dias) {
    final operacao = Map<String, dynamic>.from(cobertura['operacao']);
    final periodo = _periodo == null
        ? '${_dataBr(operacao['inicio'])} a ${_dataBr(operacao['fim'])} (tudo)'
        : '${_dataBr(_iso(_periodo!.start))} a ${_dataBr(_iso(_periodo!.end))}';
    final sugestoes = _lista(dados['sugestoesFeriado']).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Verificação do relatório mensal', style: Theme.of(context).textTheme.headlineMedium),
              ),
              PopupMenuButton<(String, String)>(
                enabled: dias.isNotEmpty,
                onSelected: (opcao) => _exportar(opcao.$1, opcao.$2),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: ('xlsx', 'tudo'), child: Text('Dados filtrados (Excel .xlsx)')),
                  PopupMenuItem(value: ('csv', 'tudo'), child: Text('Dados filtrados (CSV)')),
                  PopupMenuItem(value: ('xlsx', 'quilometragem'), child: Text('Quilometragem (Excel .xlsx)')),
                  PopupMenuItem(value: ('csv', 'quilometragem'), child: Text('Quilometragem (CSV)')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(children: [Icon(Icons.download), SizedBox(width: 6), Text('Exportar')]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _escolherPeriodo(operacao),
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
              TextButton.icon(
                onPressed: () => _abrirFeriados(dados),
                icon: const Icon(Icons.event),
                label: Text(sugestoes == 0
                    ? 'Feriados (${_lista(dados['feriados']).length})'
                    : 'Feriados (${_lista(dados['feriados']).length}) · $sugestoes dia(s) a conferir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== BLOCOS REUTILIZADOS ====================

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
            for (final coluna in colunas)
              DataColumn(label: Text(coluna, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: [
            for (final linha in linhas) DataRow(cells: [for (final celula in linha) DataCell(Text(celula))]),
          ],
        ),
      );

  /// Sem dado / ponto de atenção: sempre ícone + texto, nunca só a cor
  Widget _aviso(IconData icone, Color cor, String texto) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 18, color: cor),
            const SizedBox(width: 8),
            Expanded(child: Text(texto)),
          ],
        ),
      );

  List<String> _rotulos(List<Map<String, dynamic>> dias) => [
        for (final dia in dias) '${(dia['data'] as String).substring(8, 10)}/${(dia['data'] as String).substring(5, 7)}',
      ];

  SerieGrafico _serie(String nome, Color cor, List<Map<String, dynamic>> dias, String campo) =>
      SerieGrafico(nome, cor, [for (final dia in dias) _numero(dia[campo])]);

  String _nomeDoMes(Map<String, dynamic> mes) =>
      '${_meses[int.parse((mes['mes'] as String).substring(5))]}/${(mes['mes'] as String).substring(2, 4)}';

  /// Divergências de uma conferência que caem nos dias mostrados
  List<Map<String, dynamic>> _divergencias(dynamic importacao, String inicioDaDescricao, List<Map<String, dynamic>> dias) {
    if (importacao == null) return [];
    final datas = {for (final dia in dias) dia['data']};
    return [
      for (final conferencia in _lista(importacao['conferencias']))
        if ((conferencia['descricao'] as String).startsWith(inicioDaDescricao))
          for (final divergencia in _lista(conferencia['divergencias']))
            if (datas.contains(divergencia['data'])) divergencia,
    ];
  }

  // ==================== MÓDULO 1: DEMANDA ====================

  Widget _secaoDemanda(List<Map<String, dynamic>> dias, Map<String, dynamic> demanda) {
    final comDado = dias.where((dia) => dia['passageiros'] != null).toList();
    if (comDado.isEmpty) {
      return _secao('Demanda diária de passageiros', [const Text('Sem dados de passageiros nos filtros escolhidos.')]);
    }
    final total = _soma(comDado, 'passageiros');
    final pagantes = _soma(comDado, 'pagantes');
    final gratuitos = _soma(comDado, 'naoPagantes');
    final geral = Map<String, dynamic>.from(demanda['geral']);

    List<String> estatistica(String grupo, Map<String, dynamic> e) => [
          grupo,
          '${e['n']}',
          _inteiro.format(e['media']),
          _inteiro.format(e['mediana']),
          _inteiro.format(e['desvio']),
          _inteiro.format(e['minimo']),
          _inteiro.format(e['maximo']),
        ];

    // Pico de demanda de cada semana completa
    final picos = _lista(demanda['picosSemanais']);
    final contagem = <String, int>{};
    for (final pico in picos) {
      contagem[pico['diaSemana']] = (contagem[pico['diaSemana']] ?? 0) + 1;
    }
    final entreTercaEQuinta = picos.where((p) => const ['Ter', 'Qua', 'Qui'].contains(p['diaSemana'])).length;

    return _secao('Demanda diária de passageiros', [
      _indicadores([
        ('Demanda total', _inteiro.format(total)),
        ('Pagantes', '${_inteiro.format(pagantes)} (${_decimal.format(pagantes / total * 100)}%)'),
        ('Gratuitos', '${_inteiro.format(gratuitos)} (${_decimal.format(gratuitos / total * 100)}%)'),
        ('Média por dia', _inteiro.format(geral['media'])),
      ]),
      _CartaoGrafico(
        titulo: _demandaEmBarras ? 'Passageiros por dia (a altura da coluna é a demanda total)' : 'Passageiros por dia',
        arquivo: 'demanda_diaria',
        acoes: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.show_chart), label: Text('Linha')),
              ButtonSegment(value: true, icon: Icon(Icons.bar_chart), label: Text('Barras')),
            ],
            selected: {_demandaEmBarras},
            onSelectionChanged: (escolha) => setState(() => _demandaEmBarras = escolha.first),
          ),
        ],
        grafico: GraficoDiario(
          rotulos: _rotulos(comDado),
          empilhado: _demandaEmBarras,
          formatar: _inteiro.format,
          // As cores acompanham a série nos dois modos; em barras, pagantes + gratuitos = total
          series: [
            if (!_demandaEmBarras) _serie('Demanda total', corSerie1, comDado, 'passageiros'),
            _serie('Pagantes', corSerie2, comDado, 'pagantes'),
            _serie('Gratuitos', corSerie3, comDado, 'naoPagantes'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _tabela(
        ['Grupo', 'Dias', 'Média', 'Mediana', 'Desvio padrão', 'Menor', 'Maior'],
        [
          estatistica('Todos os dias filtrados', geral),
          for (final e in _lista(demanda['porTipo'])) estatistica(_tiposDia[e['tipo']]!, e),
          for (final e in _lista(demanda['porDiaSemana'])) estatistica(e['diaSemana'], e),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Pico de demanda da semana', style: TextStyle(fontWeight: FontWeight.bold)),
      Text(picos.isEmpty
          ? 'Não há semana completa (segunda a domingo) com passageiros nos filtros escolhidos.'
          : 'Em $entreTercaEQuinta de ${picos.length} semanas completas o dia de maior demanda foi '
              'terça, quarta ou quinta (${contagem.entries.map((e) => '${e.key}: ${e.value}').join(', ')}).'),
    ]);
  }

  // ==================== MÓDULO 2: RECEITA ====================

  Widget _secaoReceita(List<Map<String, dynamic>> dias, List<Map<String, dynamic>> meses) {
    final comDado = dias.where((dia) => dia['vendas'] != null || dia['receitaCatraca'] != null).toList();
    if (comDado.isEmpty) {
      return _secao('Receita diária', [const Text('Sem dados de receita nos filtros escolhidos.')]);
    }
    final temCatraca = comDado.any((dia) => dia['receitaCatraca'] != null);
    final diasCatraca = comDado.where((dia) => dia['receitaCatraca'] != null).length;
    String moedaOuSemDado(Map<String, dynamic> mes, List<String> campos) => (mes['dias_receitaCatraca'] as num) == 0
        ? 'sem dado'
        : _moeda.format(campos.fold<num>(0, (soma, campo) => soma + (mes[campo] as num)));

    return _secao('Receita diária', [
      _indicadores([
        ('Receita antecipada (venda de créditos)', _moeda.format(_soma(comDado, 'vendas'))),
        ('Catraca em dinheiro', temCatraca ? _moeda.format(_soma(comDado, 'receitaCatracaDinheiro')) : 'sem dado'),
        ('Catraca em cartão', temCatraca ? _moeda.format(_soma(comDado, 'receitaCatracaCartao')) : 'sem dado'),
      ]),
      _CartaoGrafico(
        titulo: 'Receita por dia',
        arquivo: 'receita_diaria',
        grafico: GraficoDiario(
          rotulos: _rotulos(comDado),
          formatar: _moedaSemCentavos.format,
          series: [
            _serie('Receita antecipada', corSerie1, comDado, 'vendas'),
            if (temCatraca) _serie('Catraca em dinheiro', corSerie2, comDado, 'receitaCatracaDinheiro'),
            if (temCatraca) _serie('Catraca em cartão', corSerie3, comDado, 'receitaCatracaCartao'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _tabela([
        'Mês',
        'Receita antecipada',
        'Catraca em dinheiro',
        'Catraca em cartão',
        'Catraca total',
        'Dias com receita de catraca',
      ], [
        for (final mes in meses)
          [
            _nomeDoMes(mes),
            _moeda.format(mes['vendas']),
            moedaOuSemDado(mes, ['receitaCatracaDinheiro']),
            moedaOuSemDado(mes, ['receitaCatracaCartao']),
            moedaOuSemDado(mes, ['receitaCatracaDinheiro', 'receitaCatracaCartao']),
            '${mes['dias_receitaCatraca']} de ${mes['dias']}',
          ],
      ]),
      if (!temCatraca)
        _aviso(Icons.info_outline, Colors.black54,
            'Receita de catraca (dinheiro e cartão): sem dado. Os relatórios do Smart Report não trazem esses valores. '
            'Envie uma planilha CSV na aba "Enviar dados" com as colunas data; receitaCatracaDinheiro; receitaCatracaCartao.')
      else if (diasCatraca < comDado.length)
        _aviso(Icons.info_outline, Colors.black54,
            'Receita de catraca informada em $diasCatraca de ${comDado.length} dias; os demais ficam sem dado.'),
    ]);
  }

  // ==================== MÓDULO 3: CRÉDITO CIRCULANTE ====================

  Widget _painelAlerta(Map<String, dynamic> alerta) {
    final (cor, icone, titulo) = switch (alerta['nivel']) {
      'vermelho' => (_corVermelho, Icons.error, 'Alerta vermelho'),
      'amarelo' => (_corAmarelo, Icons.warning_amber, 'Alerta amarelo'),
      _ => (_corNormal, Icons.check_circle, 'Sem alerta'),
    };
    final semanas = alerta['semanasSeguidas'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: cor, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(semanas == 0
                    ? 'Na última semana completa do período as validações na catraca acompanharam ou superaram as vendas de crédito.'
                    : 'O crédito circulante cresceu em $semanas semana(s) completa(s) seguida(s) até o fim do período: '
                        'vendeu-se mais crédito do que foi validado. Possível anomalia a conferir na apuração do subsídio.'),
                Text(alerta['regra'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoCirculante(List<Map<String, dynamic>> dias, dynamic alerta, dynamic importacao) {
    final comDado = dias.where((dia) => dia['circulanteAcumulado'] != null).toList();
    if (comDado.isEmpty) {
      return _secao('Crédito circulante', [const Text('Sem dados de venda e validação de créditos nos filtros escolhidos.')]);
    }
    final atencao = [
      ..._divergencias(importacao, 'Valores iguais entre emissões', dias),
      ..._divergencias(importacao, 'Saldo de créditos', dias),
    ];
    final semanas = alerta == null ? <Map<String, dynamic>>[] : _lista(alerta['semanas']);
    return _secao('Crédito circulante', [
      if (alerta != null) _painelAlerta(Map<String, dynamic>.from(alerta)),
      _indicadores([
        ('Créditos vendidos', _moeda.format(_soma(dias, 'vendas'))),
        ('Créditos validados na catraca', _moeda.format(_soma(dias, 'utilizacao'))),
        ('Crédito circulante acumulado no período', _moeda.format(comDado.last['circulanteAcumulado'])),
      ]),
      _CartaoGrafico(
        titulo: 'Crédito circulante acumulado (vendidos − validados) desde o início do período',
        arquivo: 'credito_circulante_acumulado',
        grafico: GraficoDiario(
          rotulos: _rotulos(comDado),
          formatar: _moedaSemCentavos.format,
          series: [_serie('Acumulado', corSerie1, comDado, 'circulanteAcumulado')],
        ),
      ),
      _nota('O acumulado parte de zero no primeiro dia do período escolhido (os relatórios não informam um saldo '
          'inicial) e soma todos os tipos de dia, mesmo com filtro de tipo de dia aplicado.'),
      if (semanas.isNotEmpty) ...[
        const SizedBox(height: 12),
        _tabela(
          ['Semana (segunda)', 'Créditos vendidos', 'Créditos validados', 'Variação do circulante'],
          [
            for (final s in semanas)
              [_dataBr(s['semana']), _moeda.format(s['vendas']), _moeda.format(s['utilizacao']), _moeda.format(s['circulante'])],
          ],
        ),
      ],
      for (final item in atencao)
        _aviso(Icons.warning_amber, Colors.orange, 'Ponto de atenção em ${_dataBr(item['data'])}: ${item['detalhe']}'),
    ]);
  }

  // ==================== QUILOMETRAGEM ====================

  Widget _secaoQuilometragem(List<Map<String, dynamic>> dias) {
    final comDado = dias.where((dia) => dia['kmTotal'] != null).toList();
    if (comDado.isEmpty) {
      return _secao('Quilometragem', [const Text('Sem dados de operação nos filtros escolhidos.')]);
    }
    final total = _soma(comDado, 'kmTotal');
    final improdutiva = _soma(comDado, 'kmImprodutiva');
    final programadas = _soma(comDado, 'viagensProgramadas');
    final realizadas = _soma(comDado, 'viagensRealizadas');
    return _secao('Quilometragem', [
      _indicadores([
        ('Km produtiva', _decimal.format(_soma(comDado, 'kmProdutiva'))),
        ('Km improdutiva', '${_decimal.format(improdutiva)} (${_decimal.format(improdutiva / total * 100)}%)'),
        ('Km total', _decimal.format(total)),
        ('Viagens realizadas / programadas',
            '${_inteiro.format(realizadas)} / ${_inteiro.format(programadas)} (${NumberFormat('0.00', 'pt_BR').format(realizadas / programadas * 100)}%)'),
      ]),
      _CartaoGrafico(
        titulo: 'Km por dia (a altura da coluna é o km total)',
        arquivo: 'quilometragem_diaria',
        acoes: [
          OutlinedButton.icon(
            onPressed: _abrirRelatorioQuilometragem,
            icon: const Icon(Icons.print),
            label: const Text('Relatório para impressão / PDF'),
          ),
        ],
        grafico: GraficoDiario(
          rotulos: _rotulos(comDado),
          empilhado: true,
          formatar: _decimal.format,
          series: [
            _serie('Km produtiva', corSerie1, comDado, 'kmProdutiva'),
            _serie('Km improdutiva', corSerie2, comDado, 'kmImprodutiva'),
          ],
        ),
      ),
    ]);
  }

  // ==================== RESUMO POR MÊS ====================

  Widget _secaoResumo(List<Map<String, dynamic>> meses) {
    // (rótulo, campo, campo com a quantidade de dias que têm esse dado)
    const linhas = <(String, String, String?)>[
      ('Dias com operação', 'dias_operacao', null),
      ('  Dias úteis', 'util', null),
      ('  Dias não úteis', 'nao_util', null),
      ('  Feriados', 'feriado', null),
      ('Viagens programadas', 'viagensProgramadas', 'dias_operacao'),
      ('Viagens realizadas', 'viagensRealizadas', 'dias_operacao'),
      ('Km produtiva', 'kmProdutiva', 'dias_operacao'),
      ('Km improdutiva', 'kmImprodutiva', 'dias_operacao'),
      ('Km total', 'kmTotal', 'dias_operacao'),
      ('Dias com passageiros', 'dias_passageiros', null),
      ('Demanda total de passageiros', 'passageiros', 'dias_passageiros'),
      ('Passageiros pagantes', 'pagantes', 'dias_passageiros'),
      ('Passageiros gratuitos', 'naoPagantes', 'dias_passageiros'),
      ('Dias com venda de créditos', 'dias_creditos', null),
      ('Receita antecipada (créditos vendidos)', 'vendas', 'dias_creditos'),
      ('Créditos validados na catraca', 'utilizacao', 'dias_creditos'),
      ('Crédito circulante (vendidos − validados)', 'circulante', 'dias_creditos'),
    ];
    double? media(Map<String, dynamic> mes, String campo, String? campoDias) {
      if (campoDias == null || (mes[campoDias] as num) == 0) return null;
      return (mes[campo] as num) / (mes[campoDias] as num);
    }

    // Pares comparados: cada mês com o seguinte e o primeiro com o último
    final pares = [
      for (var i = 0; i + 1 < meses.length; i++) (i, i + 1),
      if (meses.length > 2) (0, meses.length - 1),
    ];
    return _secao('Resumo por mês', [
      _tabela([
        'Indicador',
        for (final mes in meses) ...['${_nomeDoMes(mes)} total', '${_nomeDoMes(mes)} média/dia'],
        for (final (a, b) in pares) 'Variação da média ${_nomeDoMes(meses[a])} para ${_nomeDoMes(meses[b])}',
      ], [
        for (final (rotulo, campo, campoDias) in linhas)
          [
            rotulo,
            for (final mes in meses) ...[
              _valor(mes[campo], campo),
              _valor(media(mes, campo, campoDias), campo),
            ],
            for (final (a, b) in pares)
              () {
                final antes = media(meses[a], campo, campoDias);
                final depois = media(meses[b], campo, campoDias);
                // Só há variação percentual com os dois valores positivos
                if (antes == null || depois == null || antes <= 0 || depois <= 0) return '—';
                return _variacao.format((depois - antes) / antes);
              }(),
          ],
      ]),
      _nota('Os meses podem não ter a mesma quantidade de dias com dados (veja as linhas "Dias com…"). '
          'Por isso a variação compara a média por dia com dados, não os totais.'),
    ]);
  }

  // ==================== TABELA CONSOLIDADA ====================

  Widget _secaoTabelaDiaria(List<Map<String, dynamic>> dias) {
    const colunas = <(String, String)>[
      ('Demanda total', 'passageiros'),
      ('Pagantes', 'pagantes'),
      ('Gratuitos', 'naoPagantes'),
      ('Receita antecipada', 'vendas'),
      ('Catraca dinheiro', 'receitaCatracaDinheiro'),
      ('Catraca cartão', 'receitaCatracaCartao'),
      ('Créditos validados', 'utilizacao'),
      ('Circulante do dia', 'circulante'),
      ('Circulante acumulado', 'circulanteAcumulado'),
      ('Viagens progr.', 'viagensProgramadas'),
      ('Viagens realiz.', 'viagensRealizadas'),
      ('Km produtiva', 'kmProdutiva'),
      ('Km improdutiva', 'kmImprodutiva'),
      ('Km total', 'kmTotal'),
    ];
    return _secao('Tabela consolidada por dia', [
      _tabela([
        'Data',
        'Dia',
        'Tipo de dia',
        for (final (titulo, _) in colunas) titulo,
      ], [
        for (final dia in dias)
          [
            '${_dataBr(dia['data'])}${((dia['revisoes'] ?? []) as List).isEmpty ? '' : ' *'}',
            dia['diaSemana'] ?? '',
            dia['tipoDia'] == 'feriado' ? 'Feriado: ${dia['feriado']}' : (dia['tipoDia'] == 'util' ? 'Útil' : 'Não útil'),
            for (final (_, campo) in colunas) _valor(dia[campo], campo),
          ],
      ]),
      _nota('* dia com valor alterado entre uma emissão e outra do relatório (detalhes na Conferência). '
          '— indica que os arquivos enviados não trazem o dado para o dia.'),
    ]);
  }

  // ==================== COBERTURA E CONFERÊNCIA ====================

  Widget _secaoCobertura(Map<String, dynamic> cobertura, dynamic importacao) {
    String faixa(String grupo) {
      final c = cobertura[grupo];
      return c['inicio'] == null ? 'sem dado' : '${_dataBr(c['inicio'])} a ${_dataBr(c['fim'])} (${c['dias']} dias)';
    }

    final linhas = importacao == null ? <dynamic>[] : (importacao['linhas'] ?? []) as List;
    return _secao('O que os arquivos enviados trazem', [
      Text('Operação (viagens e quilometragem): ${faixa('operacao')}'),
      Text('Passageiros: ${faixa('passageiros')}'),
      Text('Venda e validação de créditos: ${faixa('creditos')}'),
      Text('Receita de catraca (dinheiro e cartão): ${faixa('receitaCatraca')}'),
      _nota('Dias fora dessas faixas ficam sem dado: nenhum valor é estimado ou preenchido.'),
      if (linhas.isNotEmpty)
        _nota('Os relatórios também detalham por linha (${linhas.join(', ')}). Este painel mostra só o total do sistema.'),
    ]);
  }

  Widget _secaoConferencia(dynamic importacao) {
    if (importacao == null) return const SizedBox.shrink();
    return _secao('Conferência dos relatórios', [
      const Text('Cruzamentos feitos entre os próprios arquivos na última leitura. '
          'Uma divergência é um ponto a verificar com o verificador, não a indicação de um erro.'),
      const SizedBox(height: 8),
      for (final conferencia in _lista(importacao['conferencias']))
        () {
          final divergencias = _lista(conferencia['divergencias']);
          final confere = divergencias.isEmpty;
          return ExpansionTile(
            leading: Icon(confere ? Icons.check_circle : Icons.warning_amber, color: confere ? _corNormal : Colors.orange),
            title: Text(conferencia['descricao']),
            subtitle: Text(confere
                ? 'Confere: ${conferencia['verificados']} verificados'
                : 'Ponto de atenção: ${divergencias.length} de ${conferencia['verificados']} não conferem'),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
            children: [
              if (confere) const Text('Nenhuma divergência.'),
              for (final d in divergencias)
                Text('${d['data'] != null ? _dataBr(d['data']) : d['arquivo']}: ${d['detalhe']}'),
            ],
          );
        }(),
    ]);
  }
}

/// Gráfico com título, ações e botão para salvar a imagem (PNG)
class _CartaoGrafico extends StatefulWidget {
  final String titulo;
  final String arquivo;
  final Widget grafico;
  final List<Widget> acoes;

  const _CartaoGrafico({required this.titulo, required this.arquivo, required this.grafico, this.acoes = const []});

  @override
  State<_CartaoGrafico> createState() => _CartaoGraficoEstado();
}

class _CartaoGraficoEstado extends State<_CartaoGrafico> {
  final _chave = GlobalKey();

  Future<void> _salvarImagem() async {
    try {
      final limite = _chave.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final imagem = await limite.toImage(pixelRatio: 2);
      final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
      baixarArquivo('${widget.arquivo}.png', 'image/png', bytes!.buffer.asUint8List());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.bold))),
            ...widget.acoes,
            IconButton(onPressed: _salvarImagem, icon: const Icon(Icons.image_outlined), tooltip: 'Salvar gráfico (PNG)'),
          ],
        ),
        RepaintBoundary(
          key: _chave,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(padding: const EdgeInsets.all(8), child: widget.grafico),
          ),
        ),
      ],
    );
  }
}

/// Cadastro de feriados. Os relatórios não trazem calendário: quem define é o gestor.
/// Devolve true ao fechar se algo mudou.
class _DialogoFeriados extends StatefulWidget {
  final List<Map<String, dynamic>> feriados;
  final List<Map<String, dynamic>> sugestoes;

  const _DialogoFeriados({required this.feriados, required this.sugestoes});

  @override
  State<_DialogoFeriados> createState() => _DialogoFeriadosEstado();
}

class _DialogoFeriadosEstado extends State<_DialogoFeriados> {
  late final List<Map<String, dynamic>> _feriados = [...widget.feriados];
  late final List<Map<String, dynamic>> _sugestoes = [...widget.sugestoes];
  final _nome = TextEditingController();
  bool _mudou = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar(String data, String nome) async {
    try {
      await ServicoApi.salvarFeriado(data, nome);
      setState(() {
        _mudou = true;
        _erro = null;
        _feriados
          ..removeWhere((f) => f['data'] == data)
          ..add({'data': data, 'nome': nome})
          ..sort((a, b) => (a['data'] as String).compareTo(b['data'] as String));
        _sugestoes.removeWhere((s) => s['data'] == data);
      });
    } catch (e) {
      setState(() => _erro = e.toString());
    }
  }

  Future<void> _excluir(String data) async {
    try {
      await ServicoApi.excluirFeriado(data);
      setState(() {
        _mudou = true;
        _erro = null;
        _feriados.removeWhere((f) => f['data'] == data);
      });
    } catch (e) {
      setState(() => _erro = e.toString());
    }
  }

  Future<void> _adicionar() async {
    final data = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (data == null) return;
    await _salvar(_iso(data), _nome.text.trim());
    _nome.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Feriados'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Os relatórios não informam feriados. Os dias cadastrados aqui passam a contar como '
                  '"Feriados" nos filtros, e não como dia útil.'),
              if (_erro != null) Text(_erro!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              if (_feriados.isEmpty) const Text('Nenhum feriado cadastrado.'),
              for (final feriado in _feriados)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${_dataBr(feriado['data'])}  ${feriado['nome'] ?? ''}'),
                  trailing: IconButton(
                    onPressed: () => _excluir(feriado['data']),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remover',
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nome,
                      decoration: const InputDecoration(labelText: 'Nome do feriado (opcional)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: _adicionar, icon: const Icon(Icons.add), label: const Text('Escolher data')),
                ],
              ),
              if (_sugestoes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Dias a conferir', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('De segunda a sexta, mas com menos viagens programadas que os dias úteis vizinhos. '
                    'Pode ser feriado ou ponto facultativo; os relatórios não dizem o motivo.'),
                for (final sugestao in _sugestoes)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${_dataBr(sugestao['data'])} (${sugestao['diaSemana']})'),
                    subtitle: Text('${sugestao['viagensProgramadas']} viagens programadas'),
                    trailing: TextButton(
                      onPressed: () => _salvar(sugestao['data'], ''),
                      child: const Text('Marcar como feriado'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _mudou), child: const Text('Fechar')),
      ],
    );
  }
}
