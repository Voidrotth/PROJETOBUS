const express = require('express');
const bcrypt = require('bcryptjs');
const roteador = express.Router();
const Usuario = require('./Usuario');
const { gerarToken, autenticar } = require('./autenticacao');
const { rota, ErroHttp } = require('./tratarErro');

// POST /api/auth/login
// Recebe { email, senha } e devolve { token, usuario }
roteador.post('/login', rota(async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) throw new ErroHttp(400, 'Informe usuário e senha');

  // "email" é o campo de usuário da tela (e-mail ou nome de usuário); só administradores entram
  const usuario = await Usuario.findOne({
    email: String(email).trim().toLowerCase(),
    papel: 'admin',
    ativo: true
  }).select('+senhaHash');
  if (!usuario || !(await bcrypt.compare(String(senha), usuario.senhaHash))) {
    throw new ErroHttp(401, 'Usuário ou senha inválidos');
  }

  const dados = usuario.toObject();
  delete dados.senhaHash;
  res.json({ token: gerarToken(usuario), usuario: dados });
}));

// GET /api/auth/eu
// Dados do usuário logado
roteador.get('/eu', autenticar, rota(async (req, res) => {
  const usuario = await Usuario.findById(req.usuario.id);
  if (!usuario || !usuario.ativo) throw new ErroHttp(401, 'Usuário inativo');
  res.json(usuario);
}));

module.exports = roteador;
