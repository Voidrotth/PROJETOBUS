import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../componentes/grafico_diario.dart';
import '../servicos/servico_api.dart';
import '../servicos/sessao.dart';
import '../tema/cores.dart';
import '../tema/espacamento.dart';
import '../tema/tipografia.dart';
import 'periodo.dart';
import 'resumo_periodo.dart';
import 'widgets.dart';

const _todosOsDias = 'util,nao_util,feriado';

final _inteiro = NumberFormat('#,##0', 'pt_BR');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
final _percentual = NumberFormat('#,##0.0%', 'pt_BR');

String _ou(double? valor, String Function(double) formatar) => valor == null ? 'sem dado' : formatar(valor);

/// Visão Geral da operação (wireframe do Figma): período, 5 indicadores e 4 gráficos.
/// Os dados são os dos relatórios do Smart Report (GET /api/indicadores); a série inteira vem
/// numa chamada só e os períodos são recortados aqui, então trocar de período é instantâneo.
class TelaVisaoGeral extends StatefulWidget {
  /// Desligado nos testes: o Socket.IO tentaria conectar num servidor de verdade
  final bool tempoReal;

  const TelaVisaoGeral({super.key, this.tempoReal = true});

  @override
  State<TelaVisaoGeral> createState() => _TelaVisaoGeralEstado();
}

class _TelaVisaoGeralEstado extends State<TelaVisaoGeral> {
  List<Map<String, dynamic>>? _dias;
  Map<String, Map<String, dynamic>> _porData = {};
  Map<String, dynamic>? _alerta;
  bool _carregando = true;
  String? _erro;

  TipoPeriodo _tipo = TipoPeriodo.diario;
  Periodo? _periodo;

  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _carregar();
    if (widget.tempoReal) _conectarTempoReal();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  // Relatórios novos processados no servidor: recarrega sem piscar a tela
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
    socket.on('dados:atualizados', (_) => _carregar(silencioso: true));
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
      final resposta = await ServicoApi.buscarIndicadores({'tipos': _todosOsDias});
      final dias = prepararDias(((resposta['dias'] ?? []) as List).cast<Map<String, dynamic>>());
      if (!mounted) return;
      setState(() {
        _dias = dias;
        _porData = {for (final dia in dias) dia['data'] as String: dia};
        _alerta = resposta['alertaCirculante'] as Map<String, dynamic>?;
        _erro = null;
        // Abre no período mais recente com dados; o escolhido continua se ainda estiver dentro dos dados
        final ultima = _ultimaData;
        if (ultima != null && (_periodo == null || _periodo!.inicio.isAfter(ultima))) {
          _periodo = Periodo.contendo(_tipo, ultima);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e is ErroApi ? e.mensagem : 'Sem conexão com o servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  DateTime? get _primeiraData => _dias == null || _dias!.isEmpty ? null : dataDeIso(_dias!.first['data'] as String);
  DateTime? get _ultimaData => _dias == null || _dias!.isEmpty ? null : dataDeIso(_dias!.last['data'] as String);

  void _trocarTipo(TipoPeriodo tipo) {
    final ultima = _ultimaData;
    if (ultima == null) return;
    // Mantém a referência: de "semana de 08/09" para mensal vai para setembro
    final atual = _periodo;
    final referencia = atual == null || atual.fim.isAfter(ultima) ? ultima : atual.fim;
    setState(() {
      _tipo = tipo;
      _periodo = Periodo.contendo(tipo, referencia);
    });
  }

  bool get _podeVoltar {
    final primeira = _primeiraData;
    return _periodo != null && primeira != null && !_periodo!.anterior().fim.isBefore(primeira);
  }

  bool get _podeAvancar {
    final ultima = _ultimaData;
    return _periodo != null && ultima != null && !_periodo!.proximo().inicio.isAfter(ultima);
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    if (dias == null && !_carregando && _erro != null) return _telaErro();

    return LayoutBuilder(builder: (context, limites) {
      final celular = limites.maxWidth < Larguras.sm;
      final margem = celular ? Esp.s4 : Esp.s8 + Esp.s1;
      final largura = (limites.maxWidth - 2 * margem).clamp(0.0, Larguras.conteudo);

      final periodo = _periodo;
      final resumo = dias == null || periodo == null ? null : ResumoPeriodo.de(dias, periodo);
      final comparado = dias == null || periodo == null ? null : ResumoPeriodo.de(dias, periodo.comparacao());

      return RefreshIndicator(
        onRefresh: _carregar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: margem, vertical: celular ? Esp.s6 : Esp.s8),
          child: Center(
            child: SizedBox(
              width: largura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cabecalho(),
                  if (_erro != null) _aviso(_erro!),
                  if (dias != null && dias.isEmpty)
                    _aviso('Nenhum relatório importado ainda. Os indicadores aparecem assim que os relatórios '
                        'do Smart Report forem processados.')
                  else ...[
                    SizedBox(height: celular ? Esp.s6 : Esp.s12),
                    _cartoes(resumo, comparado, largura),
                    SizedBox(height: celular ? Esp.s6 : Esp.s12),
                    _graficos(resumo, largura),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // ==================== CABEÇALHO ====================

  Widget _cabecalho() {
    final periodo = _periodo;
    final ultima = _ultimaData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Período', style: Estilos.tituloPagina)),
            if (ultima != null) Text('dados até ${dataBr(ultima)}', style: Estilos.tag),
            IconButton(
              onPressed: _carregando ? null : _carregar,
              icon: _carregando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            ),
          ],
        ),
        const SizedBox(height: Esp.s2),
        Wrap(
          spacing: Esp.s4,
          runSpacing: Esp.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SeletorPeriodo(selecionado: _tipo, aoSelecionar: periodo == null ? null : _trocarTipo),
            ),
            if (periodo != null)
              NavegadorPeriodo(
                rotulo: periodo.rotulo,
                aoVoltar: _podeVoltar ? () => setState(() => _periodo = periodo.anterior()) : null,
                aoAvancar: _podeAvancar ? () => setState(() => _periodo = periodo.proximo()) : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _aviso(String texto) => Padding(
        padding: const EdgeInsets.only(top: Esp.s4),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Cores.textoApagado),
            const SizedBox(width: Esp.s2),
            Expanded(child: Text(texto, style: Estilos.pequeno)),
          ],
        ),
      );

  Widget _telaErro() => Center(
        child: Padding(
          padding: const EdgeInsets.all(Esp.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Cores.erro),
              const SizedBox(height: Esp.s4),
              Text(_erro!, style: Estilos.corpo, textAlign: TextAlign.center),
              const SizedBox(height: Esp.s4),
              FilledButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
            ],
          ),
        ),
      );

  // ==================== INDICADORES ====================

  Widget _cartoes(ResumoPeriodo? r, ResumoPeriodo? anterior, double largura) {
    final comparacao = 'vs ${_tipo.comparacao}';
    final celular = largura < Larguras.sm;

    // Período com parte dos dias sem dado (ex.: semana atual, passageiros que chegam depois)
    String? cobertura(String campo) {
      if (r == null) return null;
      final comDado = r.diasCom(campo);
      return comDado > 0 && comDado < r.periodo.dias ? 'dado em $comDado de ${r.periodo.dias} dias' : null;
    }

    CartaoIndicador cartao(String titulo, String campo, String Function(ResumoPeriodo) valor,
            String? Function(ResumoPeriodo) detalhe) =>
        CartaoIndicador(
          titulo: titulo,
          valor: r == null ? null : valor(r),
          detalhe: r == null ? null : detalhe(r),
          variacao: r == null || anterior == null ? null : r.variacao(anterior, campo),
          comparacao: comparacao,
          cobertura: cobertura(campo),
          compacto: celular,
        );

    final cartoes = [
      cartao(
        'Quilometragem',
        'kmTotal',
        (r) => _ou(r.kmTotal, (v) => '${_inteiro.format(v)} km'),
        (r) => r.kmTotal == null
            ? null
            : 'produtiva ${_inteiro.format(r.kmProdutiva ?? 0)} · improdutiva ${_inteiro.format(r.kmImprodutiva ?? 0)}',
      ),
      cartao(
        'Viagens',
        'viagensRealizadas',
        (r) => _ou(r.viagensRealizadas, _inteiro.format),
        (r) => r.viagensProgramadas == null
            ? null
            : 'de ${_inteiro.format(r.viagensProgramadas)} programadas'
                '${r.cumprimento == null ? '' : ' · ${_percentual.format(r.cumprimento)}'}',
      ),
      cartao(
        'Passageiros Pagantes',
        'pagantes',
        (r) => _ou(r.pagantes, _inteiro.format),
        (r) => r.pagantes == null
            ? null
            : 'catraca ${_inteiro.format(r.catraca ?? 0)} · antecipado ${_inteiro.format(r.antecipados ?? 0)}',
      ),
      cartao(
        'Passageiros Não Pagantes',
        'naoPagantes',
        (r) => _ou(r.naoPagantes, _inteiro.format),
        (r) => r.percentualNaoPagantes == null ? null : '${_percentual.format(r.percentualNaoPagantes)} da demanda total',
      ),
      cartao(
        'Informações Financeiras',
        'receita',
        (r) => _ou(r.receita, _moeda.format),
        (r) => r.receita == null
            ? null
            : r.receitaCatraca == null
                ? 'créditos vendidos · receita de catraca sem dado'
                : 'créditos ${_moeda.format(r.vendas ?? 0)} · catraca ${_moeda.format(r.receitaCatraca)}',
      ),
    ];

    // Telas largas: os 5 numa linha, mesma altura
    if (largura >= 1200) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cartoes.length; i++) ...[
              if (i > 0) const SizedBox(width: Esp.s6),
              Expanded(child: cartoes[i]),
            ],
          ],
        ),
      );
    }
    // Tablet: 3 + 2; celular: 2 + 2 + 1, a sobra centralizada (wireframe mobile)
    final colunas = celular ? 2 : 3;
    final espaco = celular ? Esp.s3 : Esp.s6;
    final larguraCartao = (largura - espaco * (colunas - 1)) / colunas;
    return Wrap(
      spacing: espaco,
      runSpacing: espaco,
      alignment: WrapAlignment.center,
      children: [for (final c in cartoes) SizedBox(width: larguraCartao, child: c)],
    );
  }

  // ==================== GRÁFICOS ====================

  /// Dias mostrados nos gráficos: o período (até o último dia com dados); no diário, os 7 dias
  /// que terminam no dia escolhido, porque um dia só não forma gráfico.
  List<DateTime> _datasDoGrafico(Periodo periodo) {
    final ultima = _ultimaData!;
    final datas = periodo.tipo == TipoPeriodo.diario
        ? [for (var i = 6; i >= 0; i--) periodo.inicio.subtract(Duration(days: i))]
        : periodo.datas;
    return datas.where((d) => !d.isAfter(ultima)).toList();
  }

  List<double?> _serie(List<DateTime> datas, String campo) =>
      [for (final d in datas) (_porData[isoDeData(d)]?[campo] as num?)?.toDouble()];

  Widget _graficoDiario(List<DateTime> datas, List<SerieGrafico> series, String Function(double) formatar,
      {required bool empilhado, required double altura}) {
    if (series.every((s) => s.valores.every((v) => v == null))) return const SemDado();
    return GraficoDiario(
      rotulos: [for (final d in datas) diaMes(d)],
      series: series,
      formatar: formatar,
      empilhado: empilhado,
      // espaço da legenda acima do gráfico
      altura: (altura - 32).clamp(120.0, 600.0),
    );
  }

  Widget _graficos(ResumoPeriodo? r, double largura) {
    final largo = largura >= Larguras.lg;
    if (r == null) {
      // Carregando: blocos cinza do wireframe
      Widget bloco(double altura) => Container(height: altura, color: Cores.esqueleto);
      if (!largo) return Column(children: [bloco(260), const SizedBox(height: Esp.s4), bloco(260)]);
      return Column(children: [
        Row(children: [
          Expanded(flex: 5, child: bloco(380)),
          const SizedBox(width: Esp.s5),
          Expanded(flex: 3, child: bloco(380)),
        ]),
        const SizedBox(height: Esp.s10),
        Row(children: [
          Expanded(child: bloco(340)),
          const SizedBox(width: Esp.s6),
          Expanded(child: bloco(340)),
        ]),
      ]);
    }

    final datas = _datasDoGrafico(r.periodo);
    final janela = r.periodo.tipo == TipoPeriodo.diario ? ' · 7 dias até o dia escolhido' : '';
    final alturaLinha1 = largo ? 400.0 : null;
    final alturaLinha2 = largo ? 360.0 : null;

    final passageiros = PainelGrafico(
      titulo: 'Passageiros por dia',
      subtitulo: 'Pagantes e não pagantes (gratuidades)$janela',
      altura: alturaLinha1,
      construir: (altura) => _graficoDiario(
        datas,
        [
          SerieGrafico('Pagantes', Cores.primaria, _serie(datas, 'pagantes')),
          SerieGrafico('Não pagantes', Cores.destaque, _serie(datas, 'naoPagantes')),
        ],
        _inteiro.format,
        empilhado: true,
        altura: altura,
      ),
    );

    final turnos = r.turnos;
    final cumprimento = PainelGrafico(
      titulo: 'Cumprimento de viagens',
      subtitulo: 'Realizadas sobre programadas, por turno',
      altura: alturaLinha1,
      construir: (_) => r.cumprimento == null
          ? const SemDado()
          : BarrasTurnos(
              cumprimento: r.cumprimento,
              realizadas: r.viagensRealizadas,
              programadas: r.viagensProgramadas,
              turnos: turnos ?? const [],
            ),
    );

    final quilometragem = PainelGrafico(
      titulo: 'Quilometragem por dia',
      subtitulo: 'Produtiva (em linha) e improdutiva (deslocamentos)$janela',
      altura: alturaLinha2,
      construir: (altura) => _graficoDiario(
        datas,
        [
          SerieGrafico('Produtiva', Cores.primaria, _serie(datas, 'kmProdutiva')),
          SerieGrafico('Improdutiva', Cores.blue200, _serie(datas, 'kmImprodutiva')),
        ],
        _inteiro.format,
        empilhado: true,
        altura: altura,
      ),
    );

    final financeiro = PainelGrafico(
      titulo: 'Venda × validação de créditos',
      subtitulo: 'Créditos vendidos e validados na catraca$janela',
      topo: AlertaCirculante(alerta: _alerta),
      altura: alturaLinha2,
      construir: (altura) => _graficoDiario(
        datas,
        [
          SerieGrafico('Vendidos', Cores.primaria, _serie(datas, 'vendas')),
          SerieGrafico('Validados', Cores.destaque, _serie(datas, 'utilizacao')),
        ],
        _moeda.format,
        empilhado: false,
        altura: altura,
      ),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          passageiros,
          const SizedBox(height: Esp.s4),
          cumprimento,
          const SizedBox(height: Esp.s4),
          quilometragem,
          const SizedBox(height: Esp.s4),
          financeiro,
        ],
      );
    }
    // Proporções do wireframe: linha 1 em 5:3, linha 2 em 1:1
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: passageiros),
            const SizedBox(width: Esp.s5),
            Expanded(flex: 3, child: cumprimento),
          ],
        ),
        const SizedBox(height: Esp.s10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: quilometragem),
            const SizedBox(width: Esp.s6),
            Expanded(child: financeiro),
          ],
        ),
      ],
    );
  }
}
