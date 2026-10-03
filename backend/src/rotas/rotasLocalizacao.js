const express = require('express');
const roteador = express.Router();
const servicoViagem = require('../servicos/servicoViagem');
const { autenticar, exigirPapel } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

// POST /api/localizacao
// { viagemId, posicoes: [{ latitude, longitude, velocidade, direcao, precisao, horario }] }
// Também aceita uma posição só, com os campos direto no corpo.
roteador.post('/', autenticar, exigirPapel('motorista'), rota(async (req, res) => {
  const { viagemId, posicoes, ...posicaoUnica } = req.body;
  if (!viagemId) throw new ErroHttp(400, 'Campo obrigatório: viagemId');

  const resultado = await servicoViagem.registrarPosicoes(req.usuario.id, viagemId, posicoes ?? posicaoUnica);
  res.json(resultado);
}));

module.exports = roteador;
