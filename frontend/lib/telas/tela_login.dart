import 'package:flutter/material.dart';
import '../componentes/logo.dart';
import '../servicos/servico_api.dart';
import '../tema/cores.dart';
import '../tema/espacamento.dart';
import '../tema/tipografia.dart';

class TelaLogin extends StatefulWidget {
  final VoidCallback aoEntrar;

  const TelaLogin({super.key, required this.aoEntrar});

  @override
  State<TelaLogin> createState() => _TelaLoginEstado();
}

class _TelaLoginEstado extends State<TelaLogin> {
  final _chaveFormulario = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _entrando = false;
  // Motorista entra com a matrícula (a mesma dos relatórios); o painel, com o usuário
  bool _motorista = false;
  String? _erro;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_chaveFormulario.currentState!.validate()) return;
    setState(() {
      _entrando = true;
      _erro = null;
    });
    try {
      await ServicoApi.entrar(_emailCtrl.text.trim(), _senhaCtrl.text);
      widget.aoEntrar();
    } catch (e) {
      if (mounted) setState(() => _erro = e is ErroApi ? e.mensagem : 'Sem conexão com o servidor');
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _chaveFormulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: Logo(altura: 56)),
                  const SizedBox(height: Esp.s8),
                  const Text('Dashboard de Operação de Transporte',
                      textAlign: TextAlign.center, style: Estilos.tituloPagina),
                  const SizedBox(height: Esp.s1),
                  Text(_motorista ? 'Acesso do motorista' : 'Acesso da administração',
                      textAlign: TextAlign.center, style: Estilos.pequeno),
                  const SizedBox(height: Esp.s8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(labelText: _motorista ? 'Matrícula' : 'Usuário'),
                    keyboardType: _motorista ? TextInputType.number : TextInputType.text,
                    autofillHints: const [AutofillHints.username],
                    validator: (v) => (v == null || v.trim().isEmpty) ? (_motorista ? 'Informe a matrícula' : 'Informe o usuário') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senhaCtrl,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    onFieldSubmitted: (_) => _entrar(),
                    validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 16),
                    Text(_erro!, style: const TextStyle(color: Cores.erro), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _entrando ? null : _entrar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _entrando
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Entrar', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _entrando
                        ? null
                        : () => setState(() {
                              _motorista = !_motorista;
                              _erro = null;
                              _emailCtrl.clear();
                            }),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: Icon(_motorista ? Icons.admin_panel_settings : Icons.directions_bus),
                    label: Text(_motorista ? 'Sou da administração' : 'Sou motorista', style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
