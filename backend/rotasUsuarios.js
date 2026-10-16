const express = require('express');
const bcrypt = require('bcryptjs');
const roteador = express.Router();
const Usuario = require('./Usuario');
const { autenticar, exigirPapel } = require('./autenticacao');
const { rota, ErroHttp } = require('./tratarErro');

const CAMPOS_EDITAVEIS = ['nome', 'email', 'ativo'];

// Cadastro de usuários é só para administradores
roteador.use(autenticar, exigirPapel('admin'));

function camposDoCorpo(corpo) {
  const dados = {};
  for (const campo of CAMPOS_EDITAVEIS) {
    if (corpo[campo] !== undefined) dados[campo] = corpo[campo];
  }
  return dados;
}

// GET /api/usuarios
roteador.get('/', rota(async (req, res) => {
  res.json(await Usuario.find().sort({ nome: 1 }));
}));

// POST /api/usuarios
// Cria um administrador
roteador.post('/', rota(async (req, res) => {
  const { senha } = req.body;
  const dados = camposDoCorpo(req.body);
  if (!dados.nome || !dados.email || !senha) {
    throw new ErroHttp(400, 'Campos obrigatórios: nome, usuário/e-mail e senha');
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
  if (req.body.senha) {
    if (String(req.body.senha).length < 6) throw new ErroHttp(400, 'A senha precisa ter pelo menos 6 caracteres');
    alteracoes.senhaHash = await bcrypt.hash(String(req.body.senha), 10);
  }

  const usuario = await Usuario.findByIdAndUpdate(req.params.id, alteracoes, { new: true, runValidators: true });
  if (!usuario) throw new ErroHttp(404, 'Usuário não encontrado');
  res.json(usuario);
}));

module.exports = roteador;
