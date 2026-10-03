const express = require('express');
const roteador = express.Router();
const Veiculo = require('../modelos/Veiculo');
const FleetbaseService = require('../fleetbase/FleetbaseService');
const { autenticar, exigirPapel } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

roteador.use(autenticar, exigirPapel('admin'));

// GET /api/fleetbase/status
// Integração habilitada? Fleetbase respondendo? Quantos registros aguardam sincronização?
roteador.get('/status', rota(async (req, res) => {
  const [conexao, veiculosPendentes] = await Promise.all([
    FleetbaseService.verificarConexao(),
    Veiculo.countDocuments({ ativo: true, $or: [{ fleetbasePendente: true }, { fleetbaseId: null }] })
  ]);
  res.json({ ...conexao, veiculosPendentes });
}));

// GET /api/fleetbase/veiculos/:id
// Dados que o Fleetbase tem do veículo (id do PROJETOBUS)
roteador.get('/veiculos/:id', rota(async (req, res) => {
  const veiculo = await Veiculo.findById(req.params.id);
  if (!veiculo) throw new ErroHttp(404, 'Veículo não encontrado');
  if (!veiculo.fleetbaseId) throw new ErroHttp(404, 'Veículo ainda não sincronizado com o Fleetbase');
  try {
    res.json(await FleetbaseService.consultarVeiculo(veiculo.fleetbaseId));
  } catch (erro) {
    throw new ErroHttp(502, erro.message);
  }
}));

module.exports = roteador;
