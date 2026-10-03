import 'package:flutter/material.dart';
import 'servicos/sessao.dart';
import 'telas/tela_login.dart';
import 'telas/tela_painel.dart';
import 'telas/tela_verificacao.dart';
import 'telas/tela_operacao.dart';
import 'telas/tela_envio_dados.dart';
import 'telas/tela_cadastro.dart';
import 'telas/frota/tela_frota_ao_vivo.dart';
import 'telas/frota/tela_cadastros_frota.dart';
import 'telas/motorista/tela_motorista.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sessao.carregar();
  runApp(const AplicativoProjetoBus());
}

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
    if (Sessao.ehAdmin) return TelaPrincipal(aoSair: _sair);
    return TelaMotorista(aoSair: _sair);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PROJETOBUS',
      navigatorKey: _navegador,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: _telaInicial(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  final VoidCallback aoSair;

  const TelaPrincipal({super.key, required this.aoSair});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalEstado();
}

class _TelaPrincipalEstado extends State<TelaPrincipal> {
  int _indiceSelecionado = 0;

  final List<Widget> _telas = const [
    TelaPainel(),
    TelaVerificacao(),
    TelaOperacao(),
    TelaEnvioDados(),
    TelaCadastro(),
    TelaFrotaAoVivo(),
    TelaCadastrosFrota(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROJETOBUS - Sistema Operacional'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          Center(child: Text(Sessao.nome)),
          IconButton(onPressed: widget.aoSair, icon: const Icon(Icons.logout), tooltip: 'Sair'),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _indiceSelecionado,
            onDestinationSelected: (indice) {
              setState(() => _indiceSelecionado = indice);
            },
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.directions_bus, size: 36, color: Colors.blue),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Painel'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: Text('Verificação'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: Text('Operação'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file),
                label: Text('Enviar dados'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: Text('Cadastro'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Ao vivo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.directions_bus_outlined),
                selectedIcon: Icon(Icons.directions_bus),
                label: Text('Frota'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _telas[_indiceSelecionado]),
        ],
      ),
    );
  }
}
