/**
 * Única porta de entrada do PROJETOBUS para o Fleetbase.
 *
 * Regras:
 * - O MongoDB é a fonte da verdade. O Fleetbase recebe uma cópia do que interessa
 *   para frota/rastreamento (veículos, motoristas, quem está rodando e onde).
 * - Nenhum método lança erro para quem chama: falhas marcam o registro como
 *   "fleetbasePendente" e o sincronizador tenta de novo depois.
 * - Sem FLEETBASE_API_KEY tudo aqui vira no-op.
 */
const cliente = require('./clienteFleetbase');
const { veiculoParaFleetbase, motoristaParaFleetbase, posicaoParaFleetbase } = require('./adaptadores');
const Veiculo = require('../modelos/Veiculo');
const Usuario = require('../modelos/Usuario');
const Viagem = require('../modelos/Viagem');

const habilitado = cliente.fleetbaseHabilitado;

// GPS: o banco recebe todos os pontos; o Fleetbase só a posição mais recente a cada N segundos
const INTERVALO_GPS_MS = (Number(process.env.FLEETBASE_INTERVALO_GPS_SEGUNDOS) || 30) * 1000;
const ultimoEnvioGps = new Map(); // viagemId -> horário (ms) do último envio

// Aceita tanto o ObjectId quanto o documento já populado
function idDe(referencia) {
  return referencia?._id ?? referencia;
}

function idDaResposta(dados) {
  return dados?.id || dados?.data?.id || null;
}

function registrarFalha(acao, erro) {
  console.warn(`[Fleetbase] Falha ao ${acao}: ${erro.message}`);
}

// Cria ou atualiza um registro no Fleetbase; se ele foi apagado lá (404), cria de novo
async function salvarRegistro(recurso, fleetbaseId, corpo) {
  if (fleetbaseId) {
    try {
      await cliente.put(`${recurso}/${fleetbaseId}`, corpo);
      return fleetbaseId;
    } catch (erro) {
      if (erro.status !== 404) throw erro;
    }
  }
  const id = idDaResposta(await cliente.post(recurso, corpo));
  if (!id) throw new Error(`resposta sem id ao criar ${recurso}`);
  return id;
}

// ==================== CADASTROS ====================

async function sincronizarVeiculo(veiculo) {
  if (!habilitado) return null;
  try {
    const fleetbaseId = await salvarRegistro('vehicles', veiculo.fleetbaseId, veiculoParaFleetbase(veiculo));
    await Veiculo.updateOne({ _id: veiculo._id }, { fleetbaseId, fleetbasePendente: false });
    return fleetbaseId;
  } catch (erro) {
    registrarFalha(`sincronizar o veículo ${veiculo.placa}`, erro);
    await Veiculo.updateOne({ _id: veiculo._id }, { fleetbasePendente: true });
    return null;
  }
}

async function sincronizarMotorista(usuario) {
  if (!habilitado || usuario.papel !== 'motorista') return null;
  try {
    const fleetbaseId = await salvarRegistro('drivers', usuario.fleetbaseId, motoristaParaFleetbase(usuario));
    await Usuario.updateOne({ _id: usuario._id }, { fleetbaseId, fleetbasePendente: false });
    return fleetbaseId;
  } catch (erro) {
    registrarFalha(`sincronizar o motorista ${usuario.email}`, erro);
    await Usuario.updateOne({ _id: usuario._id }, { fleetbasePendente: true });
    return null;
  }
}

// Garante que motorista e veículo da viagem existem no Fleetbase e devolve os ids deles
async function idsDaViagem(viagem) {
  const [motorista, veiculo] = await Promise.all([
    Usuario.findById(idDe(viagem.motorista)),
    Veiculo.findById(idDe(viagem.veiculo))
  ]);
  const idMotorista = motorista?.fleetbaseId || (motorista && await sincronizarMotorista(motorista));
  const idVeiculo = veiculo?.fleetbaseId || (veiculo && await sincronizarVeiculo(veiculo));
  if (!idMotorista || !idVeiculo) {
    throw new Error('motorista ou veículo ainda não sincronizado');
  }
  return { idMotorista, idVeiculo, veiculo };
}

// ==================== OPERAÇÃO (VIAGEM) ====================

// Início: vincula o veículo ao motorista e coloca os dois "online" no mapa do Fleetbase
async function iniciarOperacao(viagem) {
  if (!habilitado) return;
  try {
    const { idMotorista, idVeiculo } = await idsDaViagem(viagem);
    await cliente.put(`drivers/${idMotorista}`, { vehicle: idVeiculo });
    await cliente.post(`drivers/${idMotorista}/toggle-online`, { online: true });
    await Viagem.updateOne({ _id: viagem._id }, { fleetbasePendente: false });
  } catch (erro) {
    registrarFalha(`iniciar a viagem ${viagem._id}`, erro);
    await Viagem.updateOne({ _id: viagem._id }, { fleetbasePendente: true });
  }
}

// Posição: o "track" do motorista no Fleetbase também move o veículo vinculado a ele
async function atualizarLocalizacao(viagem, posicao) {
  if (!habilitado || !posicao) return;

  const chave = String(viagem._id);
  const agora = Date.now();
  if (agora - (ultimoEnvioGps.get(chave) || 0) < INTERVALO_GPS_MS) return;
  ultimoEnvioGps.set(chave, agora);

  try {
    const motorista = await Usuario.findById(idDe(viagem.motorista)).select('fleetbaseId');
    if (!motorista?.fleetbaseId) return; // o sincronizador cria o motorista; a próxima posição chega
    await cliente.post(`drivers/${motorista.fleetbaseId}/track`, posicaoParaFleetbase(posicao));
  } catch (erro) {
    // Sem nova tentativa: a próxima posição substitui esta
    registrarFalha(`enviar posição da viagem ${chave}`, erro);
  }
}

// Encerramento: tira motorista e veículo do "online" e atualiza o hodômetro
async function encerrarOperacao(viagem) {
  ultimoEnvioGps.delete(String(viagem._id));
  if (!habilitado) return;
  try {
    const { idMotorista, idVeiculo, veiculo } = await idsDaViagem(viagem);
    await cliente.post(`drivers/${idMotorista}/toggle-online`, { online: false });
    if (veiculo.hodometro) {
      await cliente.put(`vehicles/${idVeiculo}`, { odometer: veiculo.hodometro });
    }
    await Viagem.updateOne({ _id: viagem._id }, { fleetbasePendente: false });
  } catch (erro) {
    registrarFalha(`encerrar a viagem ${viagem._id}`, erro);
    await Viagem.updateOne({ _id: viagem._id }, { fleetbasePendente: true });
  }
}

// ==================== CONSULTAS ====================

async function consultarVeiculo(fleetbaseId) {
  if (!habilitado || !fleetbaseId) return null;
  return cliente.get(`vehicles/${fleetbaseId}`);
}

async function consultarMotorista(fleetbaseId) {
  if (!habilitado || !fleetbaseId) return null;
  return cliente.get(`drivers/${fleetbaseId}`);
}

async function verificarConexao() {
  if (!habilitado) return { habilitado: false, conectado: false };
  try {
    await cliente.get('vehicles?limit=1');
    return { habilitado: true, conectado: true };
  } catch (erro) {
    return { habilitado: true, conectado: false, erro: erro.message };
  }
}

// Estes métodos rodam em segundo plano (sem await): nunca podem rejeitar,
// senão uma falha do próprio banco derrubaria o processo
function semFalhar(metodo) {
  return async (...args) => {
    try {
      return await metodo(...args);
    } catch (erro) {
      registrarFalha(metodo.name, erro);
      return null;
    }
  };
}

module.exports = {
  habilitado,
  sincronizarVeiculo: semFalhar(sincronizarVeiculo),
  sincronizarMotorista: semFalhar(sincronizarMotorista),
  iniciarOperacao: semFalhar(iniciarOperacao),
  atualizarLocalizacao: semFalhar(atualizarLocalizacao),
  encerrarOperacao: semFalhar(encerrarOperacao),
  consultarVeiculo,
  consultarMotorista,
  verificarConexao
};
