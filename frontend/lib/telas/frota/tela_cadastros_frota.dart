import 'package:flutter/material.dart';
import '../../servicos/servico_api.dart';

/// Cadastro de veículos e motoristas.
class TelaCadastrosFrota extends StatelessWidget {
  const TelaCadastrosFrota({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [
            Tab(icon: Icon(Icons.directions_bus), text: 'Veículos'),
            Tab(icon: Icon(Icons.badge), text: 'Motoristas'),
          ]),
          Expanded(child: TabBarView(children: [_ListaVeiculos(), _ListaMotoristas()])),
        ],
      ),
    );
  }
}

/// Lista genérica com carregamento, erro e botão de adicionar
class _ListaCadastro extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() carregar;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback recarregar) item;
  final Future<bool> Function(BuildContext, Map<String, dynamic>?) abrirFormulario;
  final String textoVazio;

  const _ListaCadastro({
    required this.carregar,
    required this.item,
    required this.abrirFormulario,
    required this.textoVazio,
  });

  @override
  State<_ListaCadastro> createState() => _ListaCadastroEstado();
}

class _ListaCadastroEstado extends State<_ListaCadastro> {
  List<Map<String, dynamic>> _itens = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  Future<void> _recarregar() async {
    setState(() => _carregando = true);
    try {
      final itens = await widget.carregar();
      if (mounted) {
        setState(() {
          _itens = itens;
          _erro = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_carregando) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_erro != null) {
      corpo = Center(child: Text(_erro!, style: const TextStyle(color: Colors.red)));
    } else if (_itens.isEmpty) {
      corpo = Center(child: Text(widget.textoVazio));
    } else {
      corpo = RefreshIndicator(
        onRefresh: _recarregar,
        child: ListView.separated(
          itemCount: _itens.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, indice) => widget.item(context, _itens[indice], _recarregar),
        ),
      );
    }

    return Scaffold(
      body: corpo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await widget.abrirFormulario(context, null)) _recarregar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }
}

class _ListaVeiculos extends StatelessWidget {
  const _ListaVeiculos();

  @override
  Widget build(BuildContext context) {
    return _ListaCadastro(
      carregar: ServicoApi.listarVeiculos,
      textoVazio: 'Nenhum veículo cadastrado',
      abrirFormulario: _abrirFormulario,
      item: (context, veiculo, recarregar) => ListTile(
        leading: Icon(Icons.directions_bus, color: veiculo['ativo'] == false ? Colors.grey : Colors.blue),
        title: Text('${veiculo['prefixo'] ?? ''} ${veiculo['placa']}'.trim()),
        subtitle: Text([
          '${veiculo['marca'] ?? ''} ${veiculo['modelo'] ?? ''}'.trim(),
          'Hodômetro ${veiculo['hodometro'] ?? 0} km',
          if (veiculo['consumoKmPorLitro'] != null) '${veiculo['consumoKmPorLitro']} km/L',
          if (veiculo['emUso'] == true) 'Em viagem',
          if (veiculo['ativo'] == false) 'Inativo',
        ].where((s) => s.isNotEmpty).join(' · ')),
        onTap: () async {
          if (await _abrirFormulario(context, veiculo)) recarregar();
        },
      ),
    );
  }

  static Future<bool> _abrirFormulario(BuildContext context, Map<String, dynamic>? veiculo) async {
    final campos = {
      'placa': 'Placa',
      'prefixo': 'Prefixo',
      'marca': 'Marca',
      'modelo': 'Modelo',
      'ano': 'Ano',
      'capacidade': 'Capacidade (passageiros)',
      'hodometro': 'Hodômetro (km)',
      'consumoKmPorLitro': 'Consumo médio (km por litro, ex.: 2,5)',
    };
    const numericos = {'ano', 'capacidade', 'hodometro', 'consumoKmPorLitro'};
    return _formulario(
      context,
      titulo: veiculo == null ? 'Novo veículo' : 'Editar veículo',
      campos: campos,
      numericos: numericos,
      obrigatorios: const {'placa'},
      valores: veiculo,
      ativo: veiculo?['ativo'] ?? true,
      salvar: (dados) => ServicoApi.salvarVeiculo(dados, id: veiculo?['_id']),
    );
  }
}

class _ListaMotoristas extends StatelessWidget {
  const _ListaMotoristas();

  @override
  Widget build(BuildContext context) {
    return _ListaCadastro(
      carregar: ServicoApi.listarMotoristas,
      textoVazio: 'Nenhum motorista cadastrado',
      abrirFormulario: _abrirFormulario,
      item: (context, motorista, recarregar) => ListTile(
        leading: Icon(Icons.badge, color: motorista['ativo'] == false ? Colors.grey : Colors.blue),
        title: Text(motorista['nome'] ?? ''),
        subtitle: Text([
          if ((motorista['matricula'] ?? '').isNotEmpty) 'Matrícula ${motorista['matricula']}',
          if ((motorista['cnh'] ?? '').isNotEmpty) 'CNH ${motorista['cnh']}',
          if (motorista['ativo'] == false) 'Inativo',
        ].join(' · ')),
        onTap: () async {
          if (await _abrirFormulario(context, motorista)) recarregar();
        },
      ),
    );
  }

  static Future<bool> _abrirFormulario(BuildContext context, Map<String, dynamic>? motorista) async {
    return _formulario(
      context,
      titulo: motorista == null ? 'Novo motorista' : 'Editar motorista',
      campos: {
        'nome': 'Nome',
        'matricula': 'Matrícula (login; a mesma dos relatórios)',
        'senha': motorista == null ? 'Senha (mínimo 6)' : 'Nova senha (deixe vazio para manter)',
        'email': 'E-mail (opcional)',
        'telefone': 'Telefone',
        'cnh': 'CNH',
      },
      obrigatorios: {'nome', 'matricula', if (motorista == null) 'senha'},
      senhas: const {'senha'},
      valores: motorista,
      ativo: motorista?['ativo'] ?? true,
      salvar: (dados) {
        if ((dados['senha'] ?? '').isEmpty) dados.remove('senha');
        if ((dados['email'] ?? '').isEmpty) dados.remove('email'); // sem e-mail: entra pela matrícula
        return ServicoApi.salvarUsuario({...dados, 'papel': 'motorista'}, id: motorista?['_id']);
      },
    );
  }
}

/// Diálogo de formulário simples a partir de um mapa campo → rótulo
Future<bool> _formulario(
  BuildContext context, {
  required String titulo,
  required Map<String, String> campos,
  required Future<Map<String, dynamic>> Function(Map<String, dynamic>) salvar,
  Set<String> numericos = const {},
  Set<String> obrigatorios = const {},
  Set<String> senhas = const {},
  Map<String, dynamic>? valores,
  bool ativo = true,
}) async {
  final chave = GlobalKey<FormState>();
  final controladores = {
    for (final campo in campos.keys)
      campo: TextEditingController(text: senhas.contains(campo) ? '' : '${valores?[campo] ?? ''}'),
  };
  var estaAtivo = ativo;
  var salvando = false;
  String? erro;

  final salvou = await showDialog<bool>(
    context: context,
    builder: (contexto) => StatefulBuilder(
      builder: (contexto, atualizar) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 400,
          child: Form(
            key: chave,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final campo in campos.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controladores[campo],
                        decoration: InputDecoration(labelText: campos[campo], border: const OutlineInputBorder()),
                        obscureText: senhas.contains(campo),
                        keyboardType: numericos.contains(campo) ? TextInputType.number : null,
                        validator: (v) {
                          final texto = v?.trim() ?? '';
                          if (obrigatorios.contains(campo) && texto.isEmpty) return 'Obrigatório';
                          if (numericos.contains(campo) && texto.isNotEmpty && num.tryParse(texto.replaceAll(',', '.')) == null) {
                            return 'Número inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  SwitchListTile(
                    title: const Text('Ativo'),
                    value: estaAtivo,
                    onChanged: (v) => atualizar(() => estaAtivo = v),
                  ),
                  if (erro != null) Text(erro!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: salvando
                ? null
                : () async {
                    if (!chave.currentState!.validate()) return;
                    atualizar(() => salvando = true);
                    final dados = <String, dynamic>{'ativo': estaAtivo};
                    controladores.forEach((campo, ctrl) {
                      final texto = ctrl.text.trim();
                      if (!numericos.contains(campo)) {
                        dados[campo] = texto;
                      } else if (texto.isNotEmpty) {
                        dados[campo] = num.parse(texto.replaceAll(',', '.'));
                      }
                    });
                    try {
                      await salvar(dados);
                      if (contexto.mounted) Navigator.pop(contexto, true);
                    } catch (e) {
                      atualizar(() {
                        erro = e.toString();
                        salvando = false;
                      });
                    }
                  },
            child: Text(salvando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    ),
  );

  for (final ctrl in controladores.values) {
    ctrl.dispose();
  }
  return salvou == true;
}
