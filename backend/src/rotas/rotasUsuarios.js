const express = require('express');
const bcrypt = require('bcryptjs');
const roteador = express.Router();
const Usuario = require('../modelos/Usuario');
const { autenticar, exigirPapel } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

const CAMPOS_EDITAVEIS = ['nome', 'email', 'matricula', 'papel', 'telefone', 'cnh', 'ativo'];
const MATRICULA = /^\d{1,10}$/;

// Cadastro de usuários é só para administradores
roteador.use(autenticar, exigirPapel('admin'));

function camposDoCorpo(corpo) {
  const dados = {};
  for (const campo of CAMPOS_EDITAVEIS) {
    if (corpo[campo] !== undefined) dados[campo] = corpo[campo];
  }
  return dados;
}

// GET /api/usuarios?papel=motorista
roteador.get('/', rota(async (req, res) => {
  const filtro = req.query.papel ? { papel: req.query.papel } : {};
  res.json(await Usuario.find(filtro).sort({ nome: 1 }));
}));

// POST /api/usuarios
// Cria admin ou motorista.
roteador.post('/', rota(async (req, res) => {
  const { senha } = req.body;
  const dados = camposDoCorpo(req.body);
  const motorista = (dados.papel || 'motorista') === 'motorista';
  if (motorista && !MATRICULA.test(String(dados.matricula || ''))) {
    throw new ErroHttp(400, 'Informe a matrícula do motorista (só números, como nos relatórios)');
  }
  // Motorista entra pela matrícula; o e-mail é opcional
  if (motorista && !dados.email) dados.email = `${dados.matricula}@motorista.semob`;
  if (!dados.nome || !dados.email || !senha) {
    throw new ErroHttp(400, 'Campos obrigatórios: nome, usuário/e-mail (ou matrícula) e senha');
  }
  if (String(senha).length < 6) throw new ErroHttp(400, 'A senha precisa ter pelo menos 6 caracteres');

  const usuario = await Usuario.create({
    ...dados,
    senhaHash: await bcrypt.hash(String(senha), 10)
  });

  const criado = usuario.toObject();
  delete criado.senhaHash;
  res.status(201).json(criado);
}));

// PUT /api/usuarios/:id
// Atualiza dados; "senha" é opcional
roteador.put('/:id', rota(async (req, res) => {
  const alteracoes = camposDoCorpo(req.body);
  if (alteracoes.matricula !== undefined && alteracoes.matricula !== '' && !MATRICULA.test(String(alteracoes.matricula))) {
    throw new ErroHttp(400, 'Matrícula deve ter só números');
  }
  if (req.body.senha) {
    if (String(req.body.senha).length < 6) throw new ErroHttp(400, 'A senha precisa ter pelo menos 6 caracteres');
    alteracoes.senhaHash = await bcrypt.hash(String(req.body.senha), 10);
  }

  const usuario = await Usuario.findByIdAndUpdate(req.params.id, alteracoes, { new: true, runValidators: true });
  if (!usuario) throw new ErroHttp(404, 'Usuário não encontrado');
  res.json(usuario);
}));

module.exports = roteador;
