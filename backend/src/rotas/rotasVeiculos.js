const express = require('express');
const roteador = express.Router();
const Veiculo = require('../modelos/Veiculo');
const Viagem = require('../modelos/Viagem');
const { autenticar, exigirPapel } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

const CAMPOS_EDITAVEIS = ['placa', 'prefixo', 'marca', 'modelo', 'ano', 'capacidade', 'hodometro', 'consumoKmPorLitro', 'ativo'];

roteador.use(autenticar);

function camposDoCorpo(corpo) {
  const dados = {};
  for (const campo of CAMPOS_EDITAVEIS) {
    if (corpo[campo] !== undefined) dados[campo] = corpo[campo];
  }
  return dados;
}

// GET /api/veiculos
// Motorista vê só os ativos; cada veículo vem com "emUso" (já está em viagem aberta)
roteador.get('/', rota(async (req, res) => {
  const filtro = req.usuario.papel === 'admin' ? {} : { ativo: true };
  const [veiculos, emViagem] = await Promise.all([
    Veiculo.find(filtro).sort({ prefixo: 1, placa: 1 }).lean(),
    Viagem.distinct('veiculo', { status: 'em_andamento' })
  ]);
  const emUso = new Set(emViagem.map(String));
  res.json(veiculos.map(v => ({ ...v, emUso: emUso.has(String(v._id)) })));
}));

// POST /api/veiculos
roteador.post('/', exigirPapel('admin'), rota(async (req, res) => {
  if (!req.body.placa) throw new ErroHttp(400, 'Campo obrigatório: placa');
  const veiculo = await Veiculo.create(camposDoCorpo(req.body));
  res.status(201).json(veiculo);
}));

// PUT /api/veiculos/:id
roteador.put('/:id', exigirPapel('admin'), rota(async (req, res) => {
  const veiculo = await Veiculo.findByIdAndUpdate(req.params.id, camposDoCorpo(req.body), {
    new: true,
    runValidators: true
  });
  if (!veiculo) throw new ErroHttp(404, 'Veículo não encontrado');
  res.json(veiculo);
}));

module.exports = roteador;
