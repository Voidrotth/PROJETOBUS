const Viagem = require('../modelos/Viagem');
const Veiculo = require('../modelos/Veiculo');
const Localizacao = require('../modelos/Localizacao');
const Pagamento = require('../modelos/Pagamento');
const Operacao = require('../modelos/Operacao');
const { emitirParaPainel } = require('../configuracao/tempoReal');

const FUSO_OPERACAO = process.env.FUSO_OPERACAO || 'America/Sao_Paulo';
const MAX_POSICOES_POR_ENVIO = 500;
// Pontos com precisão pior que isso (metros) ficam fora do cálculo de km
const PRECISAO_MAXIMA_KM = 50;
// Saltos acima dessa velocidade (km/h) são ruído de GPS
const VELOCIDADE_MAXIMA_KMH = 150;

class ErroViagem extends Error {
  constructor(mensagem, status = 400, dados) {
    super(mensagem);
    this.status = status;
    this.dados = dados;
  }
}

function numero(valor, padrao = 0) {
  const n = Number(valor);
  return Number.isFinite(n) ? n : padrao;
}

function formatarHorario(data) {
  return new Intl.DateTimeFormat('pt-BR', { timeZone: FUSO_OPERACAO, hour: '2-digit', minute: '2-digit' }).format(data);
}

// Resumo enviado ao painel em tempo real e na lista "ao vivo"
function resumoViagem(viagem) {
  return {
    viagemId: String(viagem._id),
    linha: viagem.linha,
    status: viagem.status,
    inicio: viagem.inicio,
    veiculo: viagem.veiculo?.placa ? { placa: viagem.veiculo.placa, prefixo: viagem.veiculo.prefixo } : null,
    motorista: viagem.motorista?.nome ? { nome: viagem.motorista.nome } : null,
    ultimaPosicao: viagem.ultimaPosicao
  };
}

async function iniciarViagem(motoristaId, { veiculoId, linha, kmInicial }) {
  if (!veiculoId || !String(linha ?? '').trim()) {
    throw new ErroViagem('Informe o veículo e a linha');
  }

  const aberta = await Viagem.findOne({ motorista: motoristaId, status: 'em_andamento' });
  if (aberta) {
    throw new ErroViagem('Você já tem uma viagem em andamento', 409, { viagem: aberta });
  }

  const veiculo = await Veiculo.findOne({ _id: veiculoId, ativo: true });
  if (!veiculo) throw new ErroViagem('Veículo não encontrado', 404);

  const emUso = await Viagem.exists({ veiculo: veiculo._id, status: 'em_andamento' });
  if (emUso) throw new ErroViagem('Este veículo já está em uma viagem em andamento', 409);

  let viagem;
  try {
    viagem = await Viagem.create({
      motorista: motoristaId,
      veiculo: veiculo._id,
      linha: String(linha).trim(),
      kmInicial: numero(kmInicial, veiculo.hodometro || 0)
    });
  } catch (erro) {
    // Índice único de viagem aberta: dois "iniciar" ao mesmo tempo
    if (erro.code === 11000) throw new ErroViagem('Motorista ou veículo já está em viagem', 409);
    throw erro;
  }

  await viagem.populate([{ path: 'veiculo', select: 'placa prefixo' }, { path: 'motorista', select: 'nome' }]);
  emitirParaPainel('viagem:iniciada', resumoViagem(viagem));
  return viagem;
}

function normalizarPosicao(bruta) {
  const latitude = Number(bruta?.latitude);
  const longitude = Number(bruta?.longitude);
  const horario = new Date(bruta?.horario ?? bruta?.timestamp);
  if (!Number.isFinite(latitude) || Math.abs(latitude) > 90) return null;
  if (!Number.isFinite(longitude) || Math.abs(longitude) > 180) return null;
  if (Number.isNaN(horario.getTime())) return null;
  return {
    latitude,
    longitude,
    velocidade: Number.isFinite(Number(bruta.velocidade)) ? Number(bruta.velocidade) : null,
    direcao: Number.isFinite(Number(bruta.direcao)) ? Number(bruta.direcao) : null,
    precisao: Number.isFinite(Number(bruta.precisao)) ? Number(bruta.precisao) : null,
    horario
  };
}

/**
 * Grava um lote de posições (a fila offline do celular manda várias de uma vez).
 * Reenvios são ignorados pelo índice único viagem + horário.
 */
async function registrarPosicoes(motoristaId, viagemId, posicoesBrutas) {
  const lista = Array.isArray(posicoesBrutas) ? posicoesBrutas : [posicoesBrutas];
  if (lista.length > MAX_POSICOES_POR_ENVIO) {
    throw new ErroViagem(`Envie no máximo ${MAX_POSICOES_POR_ENVIO} posições por vez`);
  }

  const viagem = await Viagem.findOne({ _id: viagemId, motorista: motoristaId })
    .populate('veiculo', 'placa prefixo')
    .populate('motorista', 'nome');
  if (!viagem) throw new ErroViagem('Viagem não encontrada', 404);

  // Aceita pontos entre o início e o fim da viagem (com 2 min de folga no relógio do celular)
  const folga = 2 * 60 * 1000;
  const limiteInicio = viagem.inicio.getTime() - folga;
  const limiteFim = (viagem.fim ? viagem.fim.getTime() : Date.now()) + folga;

  const posicoes = lista
    .map(normalizarPosicao)
    .filter(p => p && p.horario.getTime() >= limiteInicio && p.horario.getTime() <= limiteFim);

  if (!posicoes.length) return { recebidas: lista.length, gravadas: 0 };

  const resultado = await Localizacao.bulkWrite(posicoes.map(p => ({
    updateOne: {
      filter: { viagem: viagem._id, horario: p.horario },
      update: {
        $setOnInsert: {
          viagem: viagem._id,
          veiculo: viagem.veiculo._id,
          local: { type: 'Point', coordinates: [p.longitude, p.latitude] },
          velocidade: p.velocidade,
          direcao: p.direcao,
          precisao: p.precisao,
          horario: p.horario
        }
      },
      upsert: true
    }
  })), { ordered: false });

  const gravadas = resultado.upsertedCount || 0;
  const maisRecente = posicoes.reduce((a, b) => (b.horario > a.horario ? b : a));
  const atualizarPosicao = !viagem.ultimaPosicao || maisRecente.horario > viagem.ultimaPosicao.horario;

  const alteracoes = { $inc: { totalPosicoes: gravadas } };
  if (atualizarPosicao) alteracoes.$set = { ultimaPosicao: maisRecente };
  await Viagem.updateOne({ _id: viagem._id }, alteracoes);

  if (atualizarPosicao && viagem.status === 'em_andamento') {
    viagem.ultimaPosicao = maisRecente;
    emitirParaPainel('viagem:posicao', resumoViagem(viagem));
  }

  return { recebidas: lista.length, gravadas };
}

function distanciaKm(a, b) {
  const rad = g => (g * Math.PI) / 180;
  const [lng1, lat1] = a;
  const [lng2, lat2] = b;
  const h = Math.sin(rad(lat2 - lat1) / 2) ** 2
    + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

// Soma a distância entre pontos consecutivos, ignorando pontos imprecisos e saltos impossíveis
async function calcularKmGps(viagemId) {
  const pontos = await Localizacao.find({ viagem: viagemId })
    .sort({ horario: 1 })
    .select('local horario precisao')
    .lean();

  let total = 0;
  let anterior = null;
  for (const ponto of pontos) {
    if (ponto.precisao != null && ponto.precisao > PRECISAO_MAXIMA_KM) continue;
    if (anterior) {
      const km = distanciaKm(anterior.local.coordinates, ponto.local.coordinates);
      const horas = (ponto.horario - anterior.horario) / 3600000;
      if (horas > 0 && km / horas > VELOCIDADE_MAXIMA_KMH) continue;
      total += km;
    }
    anterior = ponto;
  }
  return Math.round(total * 10) / 10;
}

/**
 * Encerra a viagem com o fechamento do motorista e gera a Operação do painel.
 * Chamar de novo numa viagem já encerrada devolve o resultado anterior (o app pode repetir
 * o envio se a conexão cair no meio).
 */
async function encerrarViagem(motoristaId, viagemId, dados = {}) {
  const viagem = await Viagem.findOne({ _id: viagemId, motorista: motoristaId })
    .populate('veiculo')
    .populate('motorista', 'nome');
  if (!viagem) throw new ErroViagem('Viagem não encontrada', 404);

  if (viagem.status === 'encerrada') {
    const pagamento = await Pagamento.findOne({ viagem: viagem._id });
    return { viagem, pagamento };
  }

  const kmFinal = numero(dados.kmFinal, viagem.kmInicial);
  if (kmFinal < viagem.kmInicial) {
    throw new ErroViagem(`O km final (${kmFinal}) não pode ser menor que o inicial (${viagem.kmInicial})`);
  }

  const pagamentoInformado = dados.pagamento || {};
  const valores = {
    dinheiro: Math.max(0, numero(pagamentoInformado.dinheiro)),
    cartao: Math.max(0, numero(pagamentoInformado.cartao)),
    pix: Math.max(0, numero(pagamentoInformado.pix)),
    gratuidades: Math.max(0, Math.trunc(numero(pagamentoInformado.gratuidades)))
  };

  viagem.status = 'encerrada';
  viagem.fim = new Date();
  viagem.kmFinal = kmFinal;
  viagem.passageiros = Math.max(0, Math.trunc(numero(dados.passageiros)));
  viagem.voltas = Math.max(0, Math.trunc(numero(dados.voltas)));
  viagem.ocorrencias = String(dados.ocorrencias ?? '').trim();
  viagem.kmGps = await calcularKmGps(viagem._id);

  // upsert: se uma tentativa anterior parou no meio, não duplica pagamento nem operação
  const upsert = { upsert: true, new: true, setDefaultsOnInsert: true };
  const pagamento = await Pagamento.findOneAndUpdate({ viagem: viagem._id }, {
    motorista: viagem.motorista._id,
    veiculo: viagem.veiculo._id,
    linha: viagem.linha,
    data: viagem.inicio,
    ...valores,
    total: Math.round((valores.dinheiro + valores.cartao + valores.pix) * 100) / 100
  }, upsert);

  // Mesma Operação que o painel já usa para e-mail e cadastro manual
  const operacao = await Operacao.findOneAndUpdate({ viagemId: viagem._id }, {
    linha: viagem.linha,
    veiculo: viagem.veiculo.prefixo || viagem.veiculo.placa,
    motorista: viagem.motorista.nome,
    dataOperacao: viagem.inicio,
    horarioSaida: formatarHorario(viagem.inicio),
    horarioRecolhimento: formatarHorario(viagem.fim),
    kmInicial: viagem.kmInicial,
    kmFinal: viagem.kmFinal,
    passageiros: viagem.passageiros,
    viagens: viagem.voltas,
    ocorrencias: viagem.ocorrencias,
    origem: 'app'
  }, upsert);
  viagem.operacaoId = operacao._id;
  await viagem.save();

  if (kmFinal > (viagem.veiculo.hodometro || 0)) {
    await Veiculo.updateOne({ _id: viagem.veiculo._id }, { hodometro: kmFinal });
  }

  emitirParaPainel('viagem:encerrada', resumoViagem(viagem));
  return { viagem, pagamento };
}

async function trajetoDaViagem(viagemId) {
  const pontos = await Localizacao.find({ viagem: viagemId })
    .sort({ horario: 1 })
    .select('local horario velocidade -_id')
    .lean();
  return pontos.map(p => ({
    latitude: p.local.coordinates[1],
    longitude: p.local.coordinates[0],
    velocidade: p.velocidade,
    horario: p.horario
  }));
}

module.exports = {
  ErroViagem,
  resumoViagem,
  iniciarViagem,
  registrarPosicoes,
  encerrarViagem,
  trajetoDaViagem
};
