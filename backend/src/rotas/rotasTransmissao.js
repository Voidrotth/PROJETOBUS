const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const express = require('express');
const roteador = express.Router();
const Usuario = require('../modelos/Usuario');
const Veiculo = require('../modelos/Veiculo');
const Viagem = require('../modelos/Viagem');
const servicoViagem = require('../servicos/servicoViagem');
const { gerarToken } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

// "Sou motorista": transmite a localização só com nome e placa, sem cadastro nem senha.
// Devolve um token de motorista; o envio das posições e o encerramento usam as rotas normais
// (/api/localizacao e /api/viagens/:id/encerrar).
// ponytail: rota aberta (qualquer um com o endereço pode transmitir); pôr um código de acesso se o app for público

const PLACA = /^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$/; // ABC1234 ou Mercosul ABC1D23

// O motorista da transmissão é identificado pelo nome (sem acento, minúsculo)
const emailDoNome = nome => `${nome.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/[^a-z0-9]+/g, '.').replace(/^\.|\.$/g, '')}@motorista.projetobus`;

// POST /api/transmissao/iniciar  { nome, placa, linha? }
roteador.post('/iniciar', rota(async (req, res) => {
  const nome = String(req.body.nome || '').trim().replace(/\s+/g, ' ');
  const placa = String(req.body.placa || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (nome.length < 2 || nome.length > 60) throw new ErroHttp(400, 'Informe o nome do motorista');
  if (!PLACA.test(placa)) throw new ErroHttp(400, 'Placa inválida (ex.: ABC1234 ou ABC1D23)');

  const email = emailDoNome(nome);
  let motorista = await Usuario.findOne({ email });
  if (!motorista) {
    // Senha aleatória que ninguém sabe: esse motorista só entra pela transmissão
    const senhaHash = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);
    motorista = await Usuario.create({ nome, email, senhaHash, papel: 'motorista' });
  }
  if (motorista.papel !== 'motorista' || motorista.ativo === false) throw new ErroHttp(403, 'Motorista sem permissão');

  const veiculo = await Veiculo.findOne({ placa }) || await Veiculo.create({ placa });

  // Reabriu o app no meio da viagem: continua a mesma
  let viagem = await Viagem.findOne({ motorista: motorista._id, status: 'em_andamento' });
  if (viagem && String(viagem.veiculo) !== String(veiculo._id)) {
    throw new ErroHttp(409, 'Você já está transmitindo com outra placa. Pare aquela transmissão primeiro.');
  }
  if (!viagem) {
    viagem = await servicoViagem.iniciarViagem(motorista._id, {
      veiculoId: veiculo._id,
      linha: String(req.body.linha || '').trim() || 'Não informada'
    });
  }

  res.status(201).json({
    token: gerarToken(motorista),
    viagemId: viagem._id,
    motorista: { nome: motorista.nome },
    veiculo: { placa: veiculo.placa }
  });
}));

module.exports = roteador;
