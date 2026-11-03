import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../tema/cores.dart';
import '../tema/espacamento.dart';
import '../tema/tipografia.dart';
import 'resumo_periodo.dart';

final _percentual = NumberFormat('#,##0.0%', 'pt_BR');
final _inteiro = NumberFormat('#,##0', 'pt_BR');

/// Bloco cinza no lugar do conteúdo enquanto carrega (como no wireframe)
class Esqueleto extends StatelessWidget {
  final double largura;
  final double altura;

  const Esqueleto({super.key, required this.largura, required this.altura});

  @override
  Widget build(BuildContext context) => Container(
        width: largura,
        height: altura,
        decoration: BoxDecoration(color: Cores.esqueleto, borderRadius: BorderRadius.circular(2)),
      );
}

/// Abas coladas e com borda (Diário | Semanal | ... ou Passageiros | Operação | ...): só mostram o que
/// está na tela, quem troca é o cronômetro
class Abas extends StatelessWidget {
  final List<String> nomes;
  final int selecionado;

  const Abas({super.key, required this.nomes, required this.selecionado});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Cores.texto)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < nomes.length; i++) ...[
            if (i > 0) Container(width: 1, height: 36, color: Cores.texto),
            Semantics(
              selected: i == selecionado,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: Esp.s3),
                color: i == selecionado ? Cores.primaria : Cores.superficie,
                child: Text(
                  nomes[i],
                  style: TextStyle(
                    fontFamily: Fontes.corpo,
                    fontSize: 15,
                    fontWeight: i == selecionado ? FontWeight.w600 : FontWeight.w400,
                    color: i == selecionado ? Colors.white : Cores.texto,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card de um indicador: título, valor, detalhe e variação contra o período de comparação.
/// [valor] nulo = carregando (mostra o esqueleto do wireframe).
/// [subirEhBom]: true = alta em verde e queda em vermelho; false = o contrário; null = neutro (azul).
class CartaoIndicador extends StatelessWidget {
  final String titulo;
  final String? valor;
  final String? detalhe;
  final double? variacao;
  final String comparacao;
  final String? cobertura;
  final bool? subirEhBom;
  final bool compacto;

  const CartaoIndicador({
    super.key,
    required this.titulo,
    this.valor,
    this.detalhe,
    this.variacao,
    this.comparacao = '',
    this.cobertura,
    this.subirEhBom = true,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final carregando = valor == null;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compacto ? Esp.s4 : Esp.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: compacto ? Estilos.tituloCartao.copyWith(fontSize: 14) : Estilos.tituloCartao),
            const SizedBox(height: Esp.s2),
            if (carregando) ...[
              const Esqueleto(largura: 160, altura: 56),
              const SizedBox(height: Esp.s3),
              const Esqueleto(largura: 96, altura: 24),
            ] else ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor!, style: compacto ? Estilos.valor : Estilos.valorDestaque),
              ),
              if (detalhe != null) ...[
                const SizedBox(height: Esp.s1),
                Text(detalhe!, style: Estilos.pequeno, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: Esp.s3),
              _linhaVariacao(),
              if (cobertura != null) ...[const SizedBox(height: Esp.s1), Text(cobertura!, style: Estilos.tag)],
            ],
          ],
        ),
      ),
    );
  }

  Widget _linhaVariacao() {
    final v = variacao;
    if (v == null) return const Text('sem comparação', style: Estilos.tag);
    final sobe = v >= 0;
    final bom = subirEhBom == null || v == 0 ? null : sobe == subirEhBom;
    final (cor, fundo) = switch (bom) {
      true => (Cores.green700, Cores.green50),
      false => (Cores.erro, Cores.vermelho50),
      null => (Cores.primaria, Cores.blue50),
    };
    return Semantics(
      label: '${sobe ? 'Alta' : 'Queda'} de ${_percentual.format(v.abs())} $comparacao',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Esp.s2, vertical: Esp.s1),
            decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(Esp.raio)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sobe ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: cor),
                const SizedBox(width: Esp.s1),
                Text('${sobe ? '+' : ''}${_percentual.format(v)}',
                    style: Estilos.tag.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: cor)),
              ],
            ),
          ),
          const SizedBox(width: Esp.s2),
          Expanded(child: Text(comparacao, style: Estilos.tag, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Card de gráfico. Com [altura] (telas largas) o conteúdo recebe a altura que sobra;
/// sem ela (celular) o conteúdo recebe [alturaConteudoPadrao].
class PainelGrafico extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget? topo;
  final double? altura;
  final double alturaConteudoPadrao;
  final Widget Function(double alturaConteudo) construir;

  const PainelGrafico({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.construir,
    this.topo,
    this.altura,
    this.alturaConteudoPadrao = 220,
  });

  @override
  Widget build(BuildContext context) {
    final cabecalho = <Widget>[
      Text(titulo, style: Estilos.tituloCartao),
      const SizedBox(height: Esp.s1),
      Text(subtitulo, style: Estilos.pequeno),
      const SizedBox(height: Esp.s4),
      if (topo != null) ...[topo!, const SizedBox(height: Esp.s2)],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Esp.s5),
        child: altura == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [...cabecalho, construir(alturaConteudoPadrao)],
              )
            : SizedBox(
                height: altura! - 2 * Esp.s5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...cabecalho,
                    Expanded(child: LayoutBuilder(builder: (context, limites) => construir(limites.maxHeight))),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Mensagem no lugar do gráfico quando o período não tem o dado
class SemDado extends StatelessWidget {
  final String texto;

  const SemDado({super.key, this.texto = 'Sem dado neste período'});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(child: Text(texto, style: Estilos.pequeno, textAlign: TextAlign.center)),
      );
}

/// Cumprimento total e por turno em barras horizontais
class BarrasTurnos extends StatelessWidget {
  final double? cumprimento;
  final double? realizadas;
  final double? programadas;
  final List<Turno> turnos;

  const BarrasTurnos({super.key, this.cumprimento, this.realizadas, this.programadas, required this.turnos});

  @override
  Widget build(BuildContext context) {
    final naoRealizadas = realizadas == null || programadas == null ? null : programadas! - realizadas!;
    // Sem o relatório "Fator de Cumprimento de Viagem" não há detalhe por turno: mostra a barra do total
    final barras = turnos.isNotEmpty || naoRealizadas == null
        ? turnos
        : [Turno('Total do período', programadas!, realizadas!)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cumprimento != null)
          Text(_percentual.format(cumprimento), style: Estilos.valorGrande.copyWith(color: Cores.primaria)),
        if (realizadas != null && programadas != null)
          Text('${_inteiro.format(realizadas)} de ${_inteiro.format(programadas)} viagens programadas',
              style: Estilos.pequeno),
        if (naoRealizadas != null && naoRealizadas > 0)
          Text('${_inteiro.format(naoRealizadas)} ${naoRealizadas == 1 ? 'viagem não realizada' : 'viagens não realizadas'}',
              style: Estilos.pequeno.copyWith(color: Cores.erro)),
        for (final turno in barras) ...[
          const SizedBox(height: Esp.s4),
          Row(
            children: [
              Expanded(child: Text(turno.nome, style: Estilos.corpo.copyWith(fontWeight: FontWeight.w500))),
              Text(
                '${_inteiro.format(turno.realizadas)} / ${_inteiro.format(turno.programadas)}'
                '${turno.cumprimento == null ? '' : ' · ${_percentual.format(turno.cumprimento)}'}',
                style: Estilos.tag,
              ),
            ],
          ),
          const SizedBox(height: Esp.s1),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 10,
              color: Cores.secundaria,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (turno.cumprimento ?? 0).clamp(0.0, 1.0),
                heightFactor: 1,
                child: Container(color: Cores.primaria),
              ),
            ),
          ),
        ],
        if (turnos.isEmpty) ...[
          const SizedBox(height: Esp.s3),
          const Text('Por turno: sem dado neste período', style: Estilos.tag),
        ],
      ],
    );
  }
}

/// Alerta do crédito circulante calculado pelo backend (sempre com ícone e texto, não só cor)
class AlertaCirculante extends StatelessWidget {
  final Map<String, dynamic>? alerta;

  const AlertaCirculante({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) {
    final a = alerta;
    if (a == null) return const SizedBox.shrink();
    final (texto, icone, cor) = switch (a['nivel']) {
      'vermelho' => ('Crédito circulante: alerta', Icons.error, Cores.erro),
      'amarelo' => ('Crédito circulante: atenção', Icons.warning_amber, Cores.alerta),
      _ => ('Crédito circulante sem alerta', Icons.check_circle, Cores.green700),
    };
    final semanas = a['semanasSeguidas'] ?? 0;
    return Tooltip(
      message: '${a['regra'] ?? ''}\nSemanas seguidas com venda acima da validação: $semanas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: Esp.s1),
          Flexible(child: Text(texto, style: Estilos.tag.copyWith(color: Cores.texto))),
        ],
      ),
    );
  }
}
