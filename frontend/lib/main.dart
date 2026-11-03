import 'package:flutter/material.dart';
import 'servicos/sessao.dart';
import 'tema/tema.dart';
import 'telas/tela_login.dart';
import 'visao_geral/tela_visao_geral.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sessao.carregar();
  runApp(const AplicativoProjetoBus());
}

/// Dashboard para o computador da SEMOB: entra com usuário e senha de administrador e mostra a
/// Visão Geral.
class AplicativoProjetoBus extends StatefulWidget {
  const AplicativoProjetoBus({super.key});

  @override
  State<AplicativoProjetoBus> createState() => _AplicativoProjetoBusEstado();
}

class _AplicativoProjetoBusEstado extends State<AplicativoProjetoBus> {
  @override
  void initState() {
    super.initState();
    // Token expirado: volta ao login
    Sessao.aoExpirar = () => setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEMOB · Dashboard de Operação',
      theme: criarTema(),
      home: Sessao.podeVerPainel
          ? const Scaffold(body: SafeArea(child: TelaVisaoGeral()))
          : TelaLogin(aoEntrar: () => setState(() {})),
      debugShowCheckedModeBanner: false,
    );
  }
}
