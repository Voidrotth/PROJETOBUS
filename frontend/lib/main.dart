import 'package:flutter/material.dart';
import 'telas/tela_painel.dart';
import 'telas/tela_pendencias.dart';
import 'telas/tela_cadastro.dart';

void main() {
  runApp(const AplicativoProjetoBus());
}

class AplicativoProjetoBus extends StatelessWidget {
  const AplicativoProjetoBus({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PROJETOBUS',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalEstado();
}

class _TelaPrincipalEstado extends State<TelaPrincipal> {
  int _indiceSelecionado = 0;

  final List<Widget> _telas = const [
    TelaPainel(),
    TelaPendencias(),
    TelaCadastro(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROJETOBUS - Sistema Operacional'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                icon: Icon(Icons.pending_actions_outlined),
                selectedIcon: Icon(Icons.pending_actions),
                label: Text('Pendências'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: Text('Cadastro'),
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
