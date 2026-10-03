const express = require('express');
const roteador = express.Router();
const Viagem = require('../modelos/Viagem');
const Pagamento = require('../modelos/Pagamento');
const ViagemRealizada = require('../modelos/ViagemRealizada');
const servicoViagem = require('../servicos/servicoViagem');
const { autenticar, exigirPapel } = require('../middlewares/autenticacao');
const { rota, ErroHttp } = require('../middlewares/tratarErro');

roteador.use(autenticar);

const somenteMotorista = exigirPapel('motorista');
const somenteAdmin = exigirPapel('admin');
const POPULAR = [{ path: 'veiculo', select: 'placa prefixo' }, { path: 'motorista', select: 'nome' }];

// GET /api/viagens/opcoes
// Linhas que existem nos relatórios importados (para o motorista escolher, não digitar)
roteador.get('/opcoes', rota(async (req, res) => {
  const linhas = await ViagemRealizada.distinct('linha', { atividade: 'normal' });
  res.json({ linhas: linhas.filter(Boolean).sort() });
}));

// GET /api/viagens/km?inicio=AAAA-MM-DD&fim=AAAA-MM-DD  (padrão: hoje)
// Km rodados (hodômetro) e combustível estimado por ônibus, a partir das viagens do app do motorista
roteador.get('/km', somenteAdmin, rota(async (req, res) => {
  const hoje = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(new Date());
  const { inicio = hoje, fim = inicio } = req.query;
  if (![inicio, fim].every(d => /^\d{4}-\d{2}-\d{2}$/.test(d))) throw new ErroHttp(400, 'Datas no formato AAAA-MM-DD');
  res.json(await servicoViagem.kmPorVeiculo(inicio, fim));
}));

// POST /api/viagens/iniciar
// { placa, linha, kmInicial }  (o resto da viagem vem dos relatórios)
roteador.post('/iniciar', somenteMotorista, rota(async (req, res) => {
  const viagem = await servicoViagem.iniciarViagem(req.usuario.id, req.body);
  res.status(201).json(viagem);
}));

// GET /api/viagens/atual
// Viagem aberta do motorista logado (null se não houver). O app usa para retomar após reabrir.
roteador.get('/atual', somenteMotorista, rota(async (req, res) => {
  const viagem = await Viagem.findOne({ motorista: req.usuario.id, status: 'em_andamento' }).populate(POPULAR);
  res.json(viagem);
}));

// POST /api/viagens/:id/encerrar
// { kmFinal, passageiros, voltas, ocorrencias, pagamento: { dinheiro, cartao, pix, gratuidades } }
roteador.post('/:id/encerrar', somenteMotorista, rota(async (req, res) => {
  const resultado = await servicoViagem.encerrarViagem(req.usuario.id, req.params.id, req.body);
  res.json(resultado);
}));

// GET /api/viagens/ao-vivo
// Ônibus rodando agora com a última posição (estado inicial do mapa; depois chega via Socket.IO)
roteador.get('/ao-vivo', somenteAdmin, rota(async (req, res) => {
  const viagens = await Viagem.find({ status: 'em_andamento' }).populate(POPULAR);
  res.json(viagens.map(servicoViagem.resumoViagem));
}));

// GET /api/viagens?status=encerrada&data=2026-09-22
roteador.get('/', somenteAdmin, rota(async (req, res) => {
  const filtro = {};
  if (req.query.status) filtro.status = req.query.status;
  if (req.query.data) {
    const inicio = new Date(`${req.query.data}T00:00:00`);
    if (Number.isNaN(inicio.getTime())) throw new ErroHttp(400, 'Data inválida (use AAAA-MM-DD)');
    filtro.inicio = { $gte: inicio, $lt: new Date(inicio.getTime() + 24 * 3600000) };
  }
  const viagens = await Viagem.find(filtro).sort({ inicio: -1 }).limit(200).populate(POPULAR).lean();
  const pagamentos = await Pagamento.find({ viagem: { $in: viagens.map(v => v._id) } }).lean();
  const porViagem = new Map(pagamentos.map(p => [String(p.viagem), p]));
  res.json(viagens.map(v => ({ ...v, pagamento: porViagem.get(String(v._id)) || null })));
}));

// GET /api/viagens/:id/trajeto
roteador.get('/:id/trajeto', rota(async (req, res) => {
  const viagem = await Viagem.findById(req.params.id).select('motorista');
  if (!viagem) throw new ErroHttp(404, 'Viagem não encontrada');
  if (req.usuario.papel !== 'admin' && String(viagem.motorista) !== req.usuario.id) {
    throw new ErroHttp(403, 'Acesso não permitido para este usuário');
  }
  res.json(await servicoViagem.trajetoDaViagem(viagem._id));
}));

module.exports = roteador;
