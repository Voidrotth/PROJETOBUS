const express = require('express');
const bcrypt = require('bcryptjs');
const roteador = express.Router();
const Usuario = require('../modelos/Usuario');
const { gerarToken, autenticar } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

// POST /api/auth/login
// Recebe { email, senha } e devolve { token, usuario }
roteador.post('/login', rota(async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) throw new ErroHttp(400, 'Informe e-mail e senha');

  const usuario = await Usuario.findOne({ email: String(email).toLowerCase().trim(), ativo: true })
    .select('+senhaHash');
  if (!usuario || !(await bcrypt.compare(String(senha), usuario.senhaHash))) {
    throw new ErroHttp(401, 'E-mail ou senha inválidos');
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
