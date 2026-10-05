import 'package:flutter/material.dart';
import '../tema/cores.dart';
import '../tema/tipografia.dart';

/// Logo da Secretaria de Mobilidade Urbana.
/// Placeholder em texto até chegar o arquivo oficial; aí basta trocar o conteúdo por
/// Image.asset('assets/logo_semob.png', height: altura).
class Logo extends StatelessWidget {
  final double altura;

  const Logo({super.key, this.altura = 40});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SEMOB, Secretaria de Mobilidade Urbana de São Caetano do Sul',
      child: SizedBox(
        height: altura,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(gradient: Cores.degradePrimario),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SEMOB',
                    style: TextStyle(
                        fontFamily: Fontes.titulo, fontSize: altura * 0.5, height: 1, color: Cores.primaria)),
                Text('SÃO CAETANO DO SUL',
                    style: TextStyle(
                        fontFamily: Fontes.tag, fontSize: altura * 0.22, height: 1.3, color: Cores.textoApagado)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
