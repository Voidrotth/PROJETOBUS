// Reenvia ao Fleetbase o que falhou antes (Fleetbase fora do ar, rede, etc.)
const FleetbaseService = require('./FleetbaseService');
const Veiculo = require('../modelos/Veiculo');
const Usuario = require('../modelos/Usuario');
const Viagem = require('../modelos/Viagem');

const INTERVALO_MS = 60 * 1000;
const LOTE = 20;

let temporizador;
let rodando = false;

async function sincronizarPendentes() {
  if (rodando) return;
  rodando = true;
  try {
    const veiculos = await Veiculo.find({
      ativo: true,
      $or: [{ fleetbasePendente: true }, { fleetbaseId: null }]
    }).limit(LOTE);
    for (const veiculo of veiculos) await FleetbaseService.sincronizarVeiculo(veiculo);

    const motoristas = await Usuario.find({
      papel: 'motorista',
      ativo: true,
      $or: [{ fleetbasePendente: true }, { fleetbaseId: null }]
    }).limit(LOTE);
    for (const motorista of motoristas) await FleetbaseService.sincronizarMotorista(motorista);

    const viagens = await Viagem.find({ fleetbasePendente: true }).limit(LOTE);
    for (const viagem of viagens) {
      if (viagem.status === 'em_andamento') await FleetbaseService.iniciarOperacao(viagem);
      else await FleetbaseService.encerrarOperacao(viagem);
    }
  } catch (erro) {
    console.error('[Fleetbase] Erro no sincronizador:', erro.message);
  } finally {
    rodando = false;
  }
}

function iniciarSincronizadorFleetbase() {
  if (!FleetbaseService.habilitado) {
    console.log('Fleetbase desabilitado (FLEETBASE_API_KEY não definida). Frota funciona só com o banco local.');
    return;
  }
  console.log('Integração Fleetbase habilitada');
  sincronizarPendentes();
  temporizador = setInterval(sincronizarPendentes, INTERVALO_MS);
}

function pararSincronizadorFleetbase() {
  clearInterval(temporizador);
}

module.exports = { iniciarSincronizadorFleetbase, pararSincronizadorFleetbase };
