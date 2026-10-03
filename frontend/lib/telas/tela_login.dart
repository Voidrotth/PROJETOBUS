import 'package:flutter/material.dart';
import '../servicos/servico_api.dart';
import 'motorista/tela_transmissao.dart';

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
                  const Icon(Icons.directions_bus, size: 72, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text('PROJETOBUS',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder()),
                    keyboardType: TextInputType.text,
                    autofillHints: const [AutofillHints.username],
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o usuário' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senhaCtrl,
                    decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                    obscureText: true,
                    onFieldSubmitted: (_) => _entrar(),
                    validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 16),
                    Text(_erro!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
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
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const TelaTransmissao())),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Sou motorista', style: TextStyle(fontSize: 16)),
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
