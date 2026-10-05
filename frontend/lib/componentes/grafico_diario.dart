import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cores das séries (ordem fixa: a cor acompanha a série, não a posição no gráfico)
const corSerie1 = Color(0xFF2A78D6);
const corSerie2 = Color(0xFFEB6834);
const corSerie3 = Color(0xFF1BAF7A);

const _corGrade = Color(0xFFE1E0D9);
const _corEixo = Color(0xFFC3C2B7);
const _corTexto = Color(0xFF52514E);
const _corApagado = Color(0xFF898781);

class SerieGrafico {
  final String nome;
  final Color cor;

  /// Um valor por dia; nulo = sem dado naquele dia
  final List<double?> valores;

  const SerieGrafico(this.nome, this.cor, this.valores);
}

/// Gráfico de um valor por dia: colunas empilhadas ou linhas, com um único eixo.
class GraficoDiario extends StatefulWidget {
  final List<String> rotulos;
  final List<SerieGrafico> series;
  final bool empilhado;
  final String Function(double) formatar;
  final double altura;

  const GraficoDiario({
    super.key,
    required this.rotulos,
    required this.series,
    required this.formatar,
    this.empilhado = false,
    this.altura = 260,
  });

  @override
  State<GraficoDiario> createState() => _GraficoDiarioEstado();
}

class _GraficoDiarioEstado extends State<GraficoDiario> {
  static const _margemEsquerda = 72.0;
  static const _margemDireita = 12.0;

  int? _indice;

  @override
  Widget build(BuildContext context) {
    final total = widget.rotulos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Com uma série só, o título do cartão já diz o que está no gráfico
        if (widget.series.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 16, children: [for (final serie in widget.series) _legenda(serie)]),
          ),
        SizedBox(
          height: widget.altura,
          child: LayoutBuilder(builder: (context, limites) {
            final largura = limites.maxWidth - _margemEsquerda - _margemDireita;
            final passo = total == 0 ? 0.0 : largura / total;
            final indice = _indice != null && _indice! < total ? _indice : null;
            return MouseRegion(
              onHover: (evento) {
                if (total == 0) return;
                final novo = ((evento.localPosition.dx - _margemEsquerda) / passo).floor().clamp(0, total - 1).toInt();
                if (novo != _indice) setState(() => _indice = novo);
              },
              onExit: (_) => setState(() => _indice = null),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _Pintor(widget, indice, _margemEsquerda, _margemDireita),
                    ),
                  ),
                  if (indice != null) _dica(indice, _margemEsquerda + passo * (indice + 0.5), limites.maxWidth),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _legenda(SerieGrafico serie) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: serie.cor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(serie.nome, style: const TextStyle(fontSize: 12, color: _corTexto)),
        ],
      );

  // Valores do dia sob o mouse; fica do lado oposto ao cursor para não cobrir o ponto
  Widget _dica(int indice, double x, double larguraTotal) {
    final naEsquerda = x > larguraTotal / 2;
    double soma = 0;
    for (final serie in widget.series) {
      soma += serie.valores[indice] ?? 0;
    }
    return Positioned(
      top: 0,
      left: naEsquerda ? null : x + 12,
      right: naEsquerda ? larguraTotal - x + 12 : null,
      child: IgnorePointer(
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.rotulos[indice], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                for (final serie in widget.series)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, color: serie.cor),
                    const SizedBox(width: 6),
                    Text(
                      '${serie.nome}: ${serie.valores[indice] == null ? 'sem dado' : widget.formatar(serie.valores[indice]!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ]),
                if (widget.empilhado && widget.series.length > 1)
                  Text('Total: ${widget.formatar(soma)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pintor extends CustomPainter {
  final GraficoDiario grafico;
  final int? indice;
  final double margemEsquerda;
  final double margemDireita;

  static const _margemSuperior = 8.0;
  static const _margemInferior = 24.0;

  _Pintor(this.grafico, this.indice, this.margemEsquerda, this.margemDireita);

  // Passo "redondo" (1, 2, 2,5 ou 5 × potência de 10) para dividir o eixo em ~4 partes
  static double _passoRedondo(double amplitude) {
    final bruto = amplitude / 4;
    final magnitude = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
    for (final multiplo in [1.0, 2.0, 2.5, 5.0]) {
      if (multiplo * magnitude >= bruto) return multiplo * magnitude;
    }
    return 10 * magnitude;
  }

  void _texto(Canvas canvas, String texto, Offset posicao, {bool alinharDireita = false, bool centralizar = false}) {
    final pintor = TextPainter(
      text: TextSpan(text: texto, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _corApagado)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alinharDireita ? posicao.dx - pintor.width : (centralizar ? posicao.dx - pintor.width / 2 : posicao.dx);
    pintor.paint(canvas, Offset(dx, posicao.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final series = grafico.series;
    final total = grafico.rotulos.length;
    if (total == 0) return;

    final esquerda = margemEsquerda;
    final largura = size.width - margemEsquerda - margemDireita;
    final altura = size.height - _margemSuperior - _margemInferior;
    final passo = largura / total;

    // Escala: sempre inclui o zero; desce abaixo dele só se houver valor negativo (linhas)
    double minimo = 0;
    double maximo = 0;
    for (var i = 0; i < total; i++) {
      if (grafico.empilhado) {
        double soma = 0;
        for (final serie in series) {
          soma += serie.valores[i] ?? 0;
        }
        maximo = math.max(maximo, soma);
      } else {
        for (final serie in series) {
          final valor = serie.valores[i];
          if (valor == null) continue;
          maximo = math.max(maximo, valor);
          minimo = math.min(minimo, valor);
        }
      }
    }
    if (maximo == minimo) maximo = minimo + 1;
    final divisao = _passoRedondo(maximo - minimo);
    minimo = (minimo / divisao).floor() * divisao;
    maximo = (maximo / divisao).ceil() * divisao;

    double y(double valor) => _margemSuperior + altura * (1 - (valor - minimo) / (maximo - minimo));
    double x(int i) => esquerda + passo * (i + 0.5);

    // Grade e eixo de valores
    final grade = Paint()
      ..color = _corGrade
      ..strokeWidth = 1;
    for (var valor = minimo; valor <= maximo + divisao / 2; valor += divisao) {
      canvas.drawLine(Offset(esquerda, y(valor)), Offset(esquerda + largura, y(valor)), grade);
      _texto(canvas, grafico.formatar(valor), Offset(esquerda - 6, y(valor) - 7), alinharDireita: true);
    }
    canvas.drawLine(
      Offset(esquerda, y(0)),
      Offset(esquerda + largura, y(0)),
      Paint()
        ..color = _corEixo
        ..strokeWidth = 1,
    );

    // Datas: só as que cabem sem encostar uma na outra
    final salto = math.max(1, (56 / passo).ceil());
    for (var i = 0; i < total; i += salto) {
      _texto(canvas, grafico.rotulos[i], Offset(x(i), size.height - _margemInferior + 6), centralizar: true);
    }

    // Linha vertical do dia sob o mouse
    if (indice != null) {
      canvas.drawLine(
        Offset(x(indice!), _margemSuperior),
        Offset(x(indice!), _margemSuperior + altura),
        Paint()
          ..color = _corEixo
          ..strokeWidth = 1,
      );
    }

    if (grafico.empilhado) {
      // Colunas finas, com 2px de respiro entre segmentos e entre colunas
      final larguraColuna = math.max(1.0, math.min(24.0, passo - 2));
      for (var i = 0; i < total; i++) {
        double base = 0;
        for (var s = 0; s < series.length; s++) {
          final valor = series[s].valores[i] ?? 0;
          if (valor <= 0) continue;
          final topo = y(base + valor);
          final fundo = y(base) - (base > 0 ? 2 : 0);
          base += valor;
          if (fundo <= topo) continue;
          final ultimo = !series.skip(s + 1).any((outra) => (outra.valores[i] ?? 0) > 0);
          final raio = ultimo ? const Radius.circular(4) : Radius.zero;
          canvas.drawRRect(
            RRect.fromLTRBAndCorners(x(i) - larguraColuna / 2, topo, x(i) + larguraColuna / 2, fundo,
                topLeft: raio, topRight: raio),
            Paint()..color = series[s].cor,
          );
        }
      }
    } else {
      for (final serie in series) {
        final linha = Paint()
          ..color = serie.cor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
        final caminho = Path();
        var iniciar = true;
        for (var i = 0; i < total; i++) {
          final valor = serie.valores[i];
          if (valor == null) {
            iniciar = true; // dia sem dado interrompe a linha
            continue;
          }
          if (iniciar) {
            caminho.moveTo(x(i), y(valor));
          } else {
            caminho.lineTo(x(i), y(valor));
          }
          iniciar = false;
        }
        canvas.drawPath(caminho, linha);
        // Ponto em cada dia: um dia isolado (vizinhos sem dado) não forma linha e sumiria
        for (var i = 0; i < total; i++) {
          final valor = serie.valores[i];
          if (valor != null) canvas.drawCircle(Offset(x(i), y(valor)), 2.5, Paint()..color = serie.cor);
        }
        final valorNoIndice = indice == null ? null : serie.valores[indice!];
        if (valorNoIndice != null) {
          final centro = Offset(x(indice!), y(valorNoIndice));
          canvas.drawCircle(centro, 6, Paint()..color = Colors.white);
          canvas.drawCircle(centro, 4, Paint()..color = serie.cor);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Pintor anterior) => anterior.grafico != grafico || anterior.indice != indice;
}
