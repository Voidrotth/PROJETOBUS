import 'package:flutter/material.dart';
import '../tema/cores.dart';
import '../tema/tipografia.dart';

/// Brasão da Prefeitura de São Caetano do Sul (o mesmo do site) + nome da SEMOB.
/// [sobreEscuro]: texto em branco, para o cabeçalho azul-marinho do painel.
class Logo extends StatelessWidget {
  final double altura;
  final bool sobreEscuro;

  const Logo({super.key, this.altura = 40, this.sobreEscuro = false});

  @override
  Widget build(BuildContext context) {
    final corTexto = sobreEscuro ? Colors.white : Cores.primaria;
    return Semantics(
      label: 'Prefeitura de São Caetano do Sul, Secretaria de Mobilidade Urbana',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // O arquivo tem fundo branco: fica num quadro branco também sobre o azul
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ColoredBox(
              color: Colors.white,
              child: Image.asset('assets/imagens/logo_prefeitura.jpg', height: altura, width: altura),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEMOB',
                  style: TextStyle(
                      fontFamily: Fontes.titulo,
                      fontSize: altura * 0.4,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: corTexto)),
              Text('Mobilidade Urbana',
                  style: TextStyle(
                      fontFamily: Fontes.corpo,
                      fontSize: altura * 0.2,
                      height: 1.3,
                      color: sobreEscuro ? Colors.white70 : Cores.textoApagado)),
            ],
          ),
        ],
      ),
    );
  }
}
