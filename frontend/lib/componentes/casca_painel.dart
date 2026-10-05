import 'package:flutter/material.dart';
import '../servicos/sessao.dart';
import '../tema/cores.dart';
import '../tema/espacamento.dart';
import '../tema/tipografia.dart';
import 'logo.dart';

/// Uma aba do painel. Os espaços vazios do wireframe viram abas acrescentando itens à lista.
class ItemNavegacao {
  final String rotulo;
  final IconData icone;
  final Widget Function() construir;

  const ItemNavegacao({required this.rotulo, required this.icone, required this.construir});
}

/// Estrutura do painel administrativo (wireframe do Figma): barra superior com logo e abas
/// nas telas largas; no celular, logo no topo e as abas numa barra inferior.
class CascaPainel extends StatefulWidget {
  final List<ItemNavegacao> itens;
  final VoidCallback aoSair;

  const CascaPainel({super.key, required this.itens, required this.aoSair});

  @override
  State<CascaPainel> createState() => _CascaPainelEstado();
}

class _CascaPainelEstado extends State<CascaPainel> {
  int _selecionado = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, limites) {
      final largo = limites.maxWidth >= Larguras.md;
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              largo ? _barraSuperior() : _barraSuperiorCelular(),
              const Divider(),
              Expanded(child: widget.itens[_selecionado].construir()),
            ],
          ),
        ),
        bottomNavigationBar: largo ? null : _barraInferior(),
      );
    });
  }

  Widget _botaoSair() => IconButton(
        onPressed: widget.aoSair,
        icon: const Icon(Icons.logout),
        tooltip: 'Sair',
        color: Cores.textoApagado,
      );

  Widget _barraSuperior() => Container(
        height: 72,
        color: Cores.superficie,
        padding: const EdgeInsets.symmetric(horizontal: Esp.s8 + Esp.s1),
        child: Row(
          children: [
            const Logo(),
            const SizedBox(width: Esp.s12),
            for (var i = 0; i < widget.itens.length; i++) ...[
              if (i > 0) const SizedBox(width: Esp.s6),
              _abaSuperior(i),
            ],
            const Spacer(),
            if (Sessao.nome.isNotEmpty) Text(Sessao.nome, style: Estilos.pequeno),
            const SizedBox(width: Esp.s2),
            _botaoSair(),
          ],
        ),
      );

  // Aba ativa com sublinhado (wireframe: "Visao Geral" sublinhado)
  Widget _abaSuperior(int indice) {
    final ativo = indice == _selecionado;
    return Semantics(
      selected: ativo,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _selecionado = indice),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: Esp.s3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ativo ? Cores.primaria : Colors.transparent, width: 2)),
          ),
          child: Text(
            widget.itens[indice].rotulo,
            style: Estilos.corpo.copyWith(
              fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
              color: ativo ? Cores.texto : Cores.textoApagado,
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraSuperiorCelular() => Container(
        height: 56,
        width: double.infinity,
        color: Cores.superficie,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Logo(altura: 34),
            Positioned(right: Esp.s1, child: _botaoSair()),
          ],
        ),
      );

  // Barra própria: o NavigationBar do Flutter exige pelo menos 2 destinos
  Widget _barraInferior() => Container(
        decoration: const BoxDecoration(
          color: Cores.superficie,
          border: Border(top: BorderSide(color: Cores.borda)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < widget.itens.length; i++)
                  Semantics(
                    selected: i == _selecionado,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => _selecionado = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Esp.s6, vertical: Esp.s2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.itens[i].icone,
                                color: i == _selecionado ? Cores.primaria : Cores.textoApagado),
                            const SizedBox(height: Esp.s1),
                            Text(
                              widget.itens[i].rotulo,
                              style: Estilos.pequeno.copyWith(
                                fontSize: 12,
                                color: i == _selecionado ? Cores.primaria : Cores.textoApagado,
                                fontWeight: i == _selecionado ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
