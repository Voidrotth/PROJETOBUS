import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../servicos/servico_api.dart';
import '../servicos/sessao.dart';

const _todosOsDias = 'util,nao_util,feriado';
const _meses = ['', 'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
const _alertas = {
  'normal': ('Crédito circulante sem alerta', Icons.check_circle, Color(0xFF0CA30C)),
  'amarelo': ('Crédito circulante: atenção', Icons.warning_amber, Color(0xFFFAB219)),
  'vermelho': ('Crédito circulante: alerta', Icons.error, Color(0xFFD03B3B)),
};

final _inteiro = NumberFormat('#,##0', 'pt_BR');
final _decimal = NumberFormat('#,##0.0', 'pt_BR');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

String _num(dynamic v, [NumberFormat? f]) => v == null ? '—' : (f ?? _inteiro).format(v);
String _dataBr(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
List<Map<String, dynamic>> _lista(dynamic v) => ((v ?? []) as List).cast<Map<String, dynamic>>();

/// Painel inicial: o último dia e o mês mais recente dos relatórios, mais os ônibus rodando agora.
/// Atualiza sozinho quando chegam relatórios novos ou o app do motorista abre/fecha viagem.
class TelaPainel extends StatefulWidget {
  const TelaPainel({super.key});

  @override
  State<TelaPainel> createState() => _TelaPainelEstado();
}

class _TelaPainelEstado extends State<TelaPainel> {
  Map<String, dynamic>? _indicadores;
  Map<String, dynamic>? _operacaoMes;
  Map<String, dynamic>? _aoVivo;
  // Km do hodômetro e combustível por ônibus (app do motorista): hoje e mês corrente
  Map<String, dynamic>? _kmHoje;
  Map<String, dynamic>? _kmMes;
  DateTime? _kmAtualizadoEm;
  bool _carregando = true;
  String? _erro;
  DateTime? _atualizadoEm;

  io.Socket? _socket;
  bool _conectado = false;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
    _conectarTempoReal();
    // Garantia caso o tempo real caia (ou os dados entrem pelo script, que não avisa o painel)
    _relogio = Timer.periodic(const Duration(seconds: 60), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  void _conectarTempoReal() {
    final socket = io.io(
      ServicoApi.urlServidor,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': Sessao.token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );
    socket.onConnect((_) {
      if (mounted) setState(() => _conectado = true);
    });
    socket.onDisconnect((_) {
      if (mounted) setState(() => _conectado = false);
    });
    for (final evento in ['dados:atualizados', 'viagem:iniciada', 'viagem:encerrada']) {
      socket.on(evento, (_) => _carregar(silencioso: true));
    }
    // Ônibus andando: atualiza só os km (no máximo a cada 15 s, as posições chegam a cada 10 s)
    socket.on('viagem:posicao', (_) {
      final ultimo = _kmAtualizadoEm;
      if (ultimo == null || DateTime.now().difference(ultimo) > const Duration(seconds: 15)) _carregarKm();
    });
    socket.connect();
    _socket = socket;
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final indicadores = await ServicoApi.buscarIndicadores({'tipos': _todosOsDias});
      final dias = _lista(indicadores['dias']);
      Map<String, dynamic>? operacao;
      if (dias.isNotEmpty) {
        final ultimo = dias.last['data'] as String;
        operacao = await ServicoApi.buscarOperacao({
          'inicio': '${ultimo.substring(0, 7)}-01',
          'fim': ultimo,
          'tipos': _todosOsDias,
        });
      }
      Map<String, dynamic>? aoVivo;
      try {
        aoVivo = await ServicoApi.buscarPainel();
      } catch (_) {} // o resumo do app do motorista é opcional aqui
      await _carregarKm();
      if (!mounted) return;
      setState(() {
        _indicadores = indicadores;
        _operacaoMes = operacao;
        _aoVivo = aoVivo;
        _erro = null;
        _atualizadoEm = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarKm() async {
    _kmAtualizadoEm = DateTime.now();
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final resultados = await Future.wait([
        ServicoApi.kmPorVeiculo(hoje, hoje),
        ServicoApi.kmPorVeiculo('${hoje.substring(0, 7)}-01', hoje),
      ]);
      if (mounted) {
        setState(() {
          _kmHoje = resultados[0];
          _kmMes = resultados[1];
        });
      }
    } catch (_) {} // sem os km o resto do painel continua
  }

  @override
  Widget build(BuildContext context) {
    if (_indicadores == null) {
      if (_carregando) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_erro ?? 'Erro ao carregar', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    final indicadores = _indicadores!;
    final dias = _lista(indicadores['dias']);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _cabecalho(dias),
        if (_erro != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_erro!, style: const TextStyle(color: Colors.red))),
        if (dias.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum relatório enviado ainda. Use a aba "Enviar dados".'),
            ),
          )
        else ...[
          _ultimoDia(dias.last),
          _mes(indicadores, dias),
          if (_operacaoMes != null) _linhasDoMes(_operacaoMes!),
          _alertasEConferencias(indicadores),
        ],
        _secaoAoVivo(),
        _secaoKmCombustivel(),
      ],
    );
  }

  // ==================== BLOCOS ====================

  Widget _cabecalho(List<Map<String, dynamic>> dias) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Painel', style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    dias.isEmpty ? 'Sem dados' : 'Dados de ${_dataBr(dias.first['data'])} a ${_dataBr(dias.last['data'])}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            // Status do tempo real: ícone + texto, não só a cor
            Icon(Icons.circle, size: 12, color: _conectado ? const Color(0xFF0CA30C) : const Color(0xFFD03B3B)),
            const SizedBox(width: 6),
            Text(_conectado ? 'Ao vivo' : 'Reconectando…'),
            if (_atualizadoEm != null) ...[
              const SizedBox(width: 12),
              Text('atualizado ${DateFormat('HH:mm:ss').format(_atualizadoEm!)}', style: const TextStyle(color: Colors.black54)),
            ],
            IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh), tooltip: 'Atualizar agora'),
          ],
        ),
      );

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

  Widget _cartoes(List<(String, String, IconData, Color)> itens) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (titulo, valor, icone, cor) in itens)
            SizedBox(
              width: 200,
              child: Card(
                elevation: 0,
                color: cor.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icone, color: cor),
                      const SizedBox(height: 8),
                      Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(titulo, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  String _cumprimento(dynamic realizadas, dynamic programadas) =>
      realizadas == null || programadas == null || programadas == 0
          ? '—'
          : '${NumberFormat('0.00', 'pt_BR').format(realizadas / programadas * 100)}%';

  Widget _ultimoDia(Map<String, dynamic> d) => _secao('Último dia com dados: ${_dataBr(d['data'])} (${d['diaSemana']})', [
        _cartoes([
          ('Viagens realizadas', '${_num(d['viagensRealizadas'])} / ${_num(d['viagensProgramadas'])}', Icons.route, Colors.blue),
          ('Cumprimento', _cumprimento(d['viagensRealizadas'], d['viagensProgramadas']), Icons.fact_check, Colors.green),
          ('Km total', _num(d['kmTotal'], _decimal), Icons.speed, Colors.purple),
          ('Ônibus em operação', _num(d['veiculos']), Icons.directions_bus, Colors.teal),
          ('Passageiros', _num(d['passageiros']), Icons.people, Colors.orange),
          ('Vendas de crédito', d['vendas'] == null ? '—' : _moeda.format(d['vendas']), Icons.payments, Colors.indigo),
        ]),
        if (d['passageiros'] == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Passageiros: o relatório desse dia ainda não chegou.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]);

  Widget _mes(Map<String, dynamic> indicadores, List<Map<String, dynamic>> dias) {
    final m = _lista(indicadores['meses']).last;
    final mes = m['mes'] as String;
    final nomeMes = '${_meses[int.parse(mes.substring(5))]}/${mes.substring(0, 4)}';
    final naoCumpridas = _operacaoMes == null ? null : _lista(_operacaoMes!['naoCumpridas']?['lista']).length;
    return _secao('Mês de $nomeMes (${_dataBr(m['inicio'])} a ${_dataBr(m['fim'])}, ${m['dias']} dias)', [
      _cartoes([
        ('Viagens realizadas', _num(m['viagensRealizadas']), Icons.route, Colors.blue),
        ('Cumprimento', _cumprimento(m['viagensRealizadas'], m['viagensProgramadas']), Icons.fact_check, Colors.green),
        ('Viagens não cumpridas', _num(naoCumpridas), Icons.cancel_outlined, Colors.red),
        ('Km total', _num(m['kmTotal'], _decimal), Icons.speed, Colors.purple),
        ('Passageiros', _num(m['passageiros']), Icons.people, Colors.orange),
        ('Vendas de crédito', _moeda.format(m['vendas'] ?? 0), Icons.payments, Colors.indigo),
        ('Créditos utilizados', _moeda.format(m['utilizacao'] ?? 0), Icons.credit_card, Colors.brown),
      ]),
    ]);
  }

  Widget _linhasDoMes(Map<String, dynamic> operacao) {
    final linhas = [..._lista(operacao['porLinha'])]..sort((a, b) => (b['viagens'] as num).compareTo(a['viagens'] as num));
    final nc = {for (final x in _lista(operacao['naoCumpridas']?['porLinha'])) x['linha']: x['quantidade']};
    return _secao('Linhas no mês', [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 32,
          columns: const [
            DataColumn(label: Text('Linha', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Viagens', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Km produtiva', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Ônibus', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Não cumpridas', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: [
            for (final l in linhas)
              DataRow(cells: [
                DataCell(Text('Linha ${l['linha']}')),
                DataCell(Text(_num(l['viagens']))),
                DataCell(Text(_num(l['kmProdutiva'], _decimal))),
                DataCell(Text(_num(l['veiculos']))),
                DataCell(Text(_num(nc[l['linha']] ?? 0))),
              ]),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Detalhes por horário, ônibus e viagem na aba Operação.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    ]);
  }

  Widget _alertasEConferencias(Map<String, dynamic> indicadores) {
    final alerta = indicadores['alertaCirculante'];
    final conferencias = _lista(indicadores['importacao']?['conferencias']);
    final comAtencao = conferencias.where((c) => (c['divergencias'] as List).isNotEmpty).length;
    final sugestoes = _lista(indicadores['sugestoesFeriado']).length;
    Widget linha(IconData icone, Color cor, String texto) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Icon(icone, color: cor, size: 20), const SizedBox(width: 8), Expanded(child: Text(texto))]),
        );
    final (rotulo, icone, cor) = _alertas[alerta?['nivel']] ?? _alertas['normal']!;
    return _secao('Alertas', [
      if (alerta != null) linha(icone, cor, '$rotulo (${alerta['semanasSeguidas']} semana(s) seguidas com vendas acima das validações)'),
      comAtencao == 0
          ? linha(Icons.check_circle, const Color(0xFF0CA30C), 'Todas as ${conferencias.length} conferências entre relatórios fecharam')
          : linha(Icons.warning_amber, const Color(0xFFFAB219),
              '$comAtencao de ${conferencias.length} conferências entre relatórios têm pontos de atenção (aba Verificação)'),
      if (sugestoes > 0)
        linha(Icons.event, const Color(0xFFFAB219), '$sugestoes dia(s) útil(eis) com programação reduzida: confira se foram feriados (aba Verificação)'),
    ]);
  }

  Widget _secaoAoVivo() {
    final v = _aoVivo;
    return _secao('Agora (app do motorista)', [
      if (v == null)
        const Text('Resumo do app do motorista indisponível.')
      else
        _cartoes([
          ('Ônibus rodando agora', _num(v['viagensEmAndamento'] ?? 0), Icons.gps_fixed, Colors.teal),
          ('Arrecadação lançada', _moeda.format(v['arrecadacao']?['total'] ?? 0), Icons.payments, Colors.green),
        ]),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('O mapa com os ônibus em tempo real fica na aba "Ao vivo" (precisa de motoristas usando o app).',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    ]);
  }

  // Km rodados por ônibus (hodômetro informado pelo motorista) e combustível estimado pelo consumo de
  // referência do ônibus (km/L, cadastrado em Frota) até chegarem os relatórios de abastecimento
  Widget _secaoKmCombustivel() {
    final hoje = _kmHoje;
    final mes = _kmMes;
    if (hoje == null || mes == null) return const SizedBox.shrink();
    final th = Map<String, dynamic>.from(hoje['totais']);
    final tm = Map<String, dynamic>.from(mes['totais']);
    final veiculos = _lista(mes['veiculos']);
    final hojePorPlaca = {for (final v in _lista(hoje['veiculos'])) v['placa']: v};
    String litros(dynamic v) => v == null ? '—' : '${_decimal.format(v)} L';
    return _secao('Km e combustível por ônibus (app do motorista)', [
      _cartoes([
        ('Km hoje', _num(th['kmTotal'], _decimal), Icons.speed, Colors.purple),
        ('Combustível hoje (estimado)', litros(th['litrosEstimados']), Icons.local_gas_station, Colors.orange),
        ('Km no mês', _num(tm['kmTotal'], _decimal), Icons.calendar_month, Colors.blue),
        ('Combustível no mês (estimado)', litros(tm['litrosEstimados']), Icons.local_gas_station, Colors.deepOrange),
        ('Média da frota', tm['kmPorLitro'] == null ? '—' : '${_decimal.format(tm['kmPorLitro'])} km/L', Icons.eco, Colors.green),
      ]),
      const SizedBox(height: 12),
      if (veiculos.isEmpty)
        const Text('Nenhuma viagem pelo app do motorista neste mês.')
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 32,
            columns: const [
              DataColumn(label: Text('Ônibus', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Km hoje', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Km no mês', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Viagens no mês', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Consumo (km/L)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Combustível no mês', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Situação', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: [
              for (final v in veiculos)
                DataRow(cells: [
                  DataCell(Text([if ((v['prefixo'] ?? '').isNotEmpty) v['prefixo'], v['placa']].join(' · '))),
                  DataCell(Text(_num(hojePorPlaca[v['placa']]?['kmTotal'] ?? 0, _decimal))),
                  DataCell(Text(_num(v['kmTotal'], _decimal))),
                  DataCell(Text(_num(v['viagens']))),
                  DataCell(Text(_num(v['consumoKmPorLitro'], _decimal))),
                  DataCell(Text(litros(v['litrosEstimados']))),
                  DataCell(Text((v['emAndamento'] ?? 0) > 0 ? 'Rodando agora' : '—')),
                ]),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Km = hodômetro final − inicial informado pelo motorista (viagem rodando: km do GPS até agora). '
          'Combustível estimado = km ÷ consumo médio do ônibus (Frota → editar ônibus). '
          '${(tm['veiculosSemConsumo'] ?? 0) > 0 ? '${tm['veiculosSemConsumo']} ônibus sem consumo cadastrado. ' : ''}'
          'Os litros reais entram quando chegarem os relatórios de abastecimento.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    ]);
  }
}
