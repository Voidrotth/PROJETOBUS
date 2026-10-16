const express = require('express');
const roteador = express.Router();
const Veiculo = require('./Veiculo');
const { autenticar, exigirPapel } = require('./autenticacao');
const { rota, ErroHttp } = require('./tratarErro');

const CAMPOS_EDITAVEIS = ['placa', 'prefixo', 'marca', 'modelo', 'ano', 'capacidade', 'ativo'];

// Cadastro de veículos é só para administradores
roteador.use(autenticar, exigirPapel('admin'));

function camposDoCorpo(corpo) {
  const dados = {};
  for (const campo of CAMPOS_EDITAVEIS) {
    if (corpo[campo] !== undefined) dados[campo] = corpo[campo];
  }
  return dados;
}

// GET /api/veiculos
roteador.get('/', rota(async (req, res) => {
  res.json(await Veiculo.find().sort({ prefixo: 1, placa: 1 }).lean());
}));

// POST /api/veiculos
roteador.post('/', rota(async (req, res) => {
  if (!req.body.placa) throw new ErroHttp(400, 'Campo obrigatório: placa');
  const veiculo = await Veiculo.create(camposDoCorpo(req.body));
  res.status(201).json(veiculo);
}));

// PUT /api/veiculos/:id
roteador.put('/:id', rota(async (req, res) => {
  const veiculo = await Veiculo.findByIdAndUpdate(req.params.id, camposDoCorpo(req.body), {
    new: true,
    runValidators: true
  });
  if (!veiculo) throw new ErroHttp(404, 'Veículo não encontrado');
  res.json(veiculo);
}));

module.exports = roteador;
