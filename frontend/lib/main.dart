import 'package:flutter/material.dart';
import 'componentes/casca_painel.dart';
import 'servicos/sessao.dart';
import 'tema/tema.dart';
import 'telas/tela_login.dart';
import 'telas/motorista/tela_motorista.dart';
import 'visao_geral/tela_visao_geral.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sessao.carregar();
  runApp(const AplicativoProjetoBus());
}

/// Abas do painel administrativo. As telas antigas (Verificação, Operação, Enviar dados, Ao vivo,
/// Frota) continuam em lib/telas e podem voltar como abas acrescentando um item aqui.
final _abasDoPainel = [
  ItemNavegacao(rotulo: 'Visão Geral', icone: Icons.dashboard_outlined, construir: () => const TelaVisaoGeral()),
];

class AplicativoProjetoBus extends StatefulWidget {
  const AplicativoProjetoBus({super.key});

  @override
  State<AplicativoProjetoBus> createState() => _AplicativoProjetoBusEstado();
}

class _AplicativoProjetoBusEstado extends State<AplicativoProjetoBus> {
  final _navegador = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Token expirado: fecha as telas abertas e volta ao login
    Sessao.aoExpirar = () {
      _navegador.currentState?.popUntil((rota) => rota.isFirst);
      setState(() {});
    };
  }

  Future<void> _sair() async {
    await Sessao.sair();
    setState(() {});
  }

  Widget _telaInicial() {
    if (!Sessao.logado) return TelaLogin(aoEntrar: () => setState(() {}));
    if (Sessao.ehAdmin) return CascaPainel(itens: _abasDoPainel, aoSair: _sair);
    return TelaMotorista(aoSair: _sair);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEMOB · Dashboard de Operação',
      navigatorKey: _navegador,
      theme: criarTema(),
      home: _telaInicial(),
      debugShowCheckedModeBanner: false,
    );
  }
}
