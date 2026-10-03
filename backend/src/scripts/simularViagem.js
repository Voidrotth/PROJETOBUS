// Simula um motorista usando o app: entra, inicia uma viagem e manda posições de GPS pela API,
// para testar o mapa da aba "Ao vivo" sem celular. Ctrl+C encerra a viagem.
// Uso: npm run simular-viagem -- <email do admin> <senha do admin> [minutos=5] [linha=02]
require('dotenv').config();

const API = `http://localhost:${process.env.PORT || 3000}/api`;
const [EMAIL_ADMIN, SENHA_ADMIN, MINUTOS = '5', LINHA = '02'] = process.argv.slice(2);
const MOTORISTA = { nome: 'Motorista Simulado', email: 'simulador@semob.com', senha: 'simulador123', papel: 'motorista' };
const VEICULO = { placa: 'SIM0001', prefixo: '9999', modelo: 'Ônibus simulado' };
const INTERVALO_MS = 3000;

// Volta em São Caetano do Sul (estação ↔ bairro); o ônibus percorre os pontos em loop
const PERCURSO = [
  [-23.6181, -46.5560], [-23.6205, -46.5612], [-23.6238, -46.5655], [-23.6279, -46.5689],
  [-23.6321, -46.5701], [-23.6352, -46.5668], [-23.6340, -46.5610], [-23.6301, -46.5571],
  [-23.6255, -46.5548], [-23.6212, -46.5541]
];

async function chamar(metodo, caminho, corpo, token) {
  const resposta = await fetch(API + caminho, {
    method: metodo,
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
    body: corpo && JSON.stringify(corpo)
  });
  const dados = await resposta.json().catch(() => null);
  if (!resposta.ok) throw Object.assign(new Error(dados?.erro || `HTTP ${resposta.status}`), { status: resposta.status, dados });
  return dados;
}

const entrar = async (email, senha) => (await chamar('POST', '/auth/login', { email, senha })).token;

async function prepararMotoristaEVeiculo(tokenAdmin) {
  const veiculos = await chamar('GET', '/veiculos', null, tokenAdmin);
  const veiculo = veiculos.find(v => v.placa === VEICULO.placa) || await chamar('POST', '/veiculos', VEICULO, tokenAdmin);
  try {
    await chamar('POST', '/usuarios', MOTORISTA, tokenAdmin);
    console.log(`Motorista de teste criado: ${MOTORISTA.email}`);
  } catch (erro) {
    if (![400, 409].includes(erro.status)) throw erro; // já existe
  }
  return veiculo;
}

// Interpola entre os pontos do percurso para o movimento ficar contínuo
function posicao(passo) {
  const POR_TRECHO = 5;
  const trecho = Math.floor(passo / POR_TRECHO) % PERCURSO.length;
  const t = (passo % POR_TRECHO) / POR_TRECHO;
  const [a, b] = [PERCURSO[trecho], PERCURSO[(trecho + 1) % PERCURSO.length]];
  const latitude = a[0] + (b[0] - a[0]) * t;
  const longitude = a[1] + (b[1] - a[1]) * t;
  const direcao = (Math.atan2(b[1] - a[1], b[0] - a[0]) * 180) / Math.PI;
  return { latitude, longitude, velocidade: 25 + Math.random() * 10, direcao: (direcao + 360) % 360, precisao: 8, horario: new Date().toISOString() };
}

async function principal() {
  if (!EMAIL_ADMIN || !SENHA_ADMIN) {
    console.log('Uso: npm run simular-viagem -- <email do admin> <senha do admin> [minutos=5] [linha=02]');
    process.exit(1);
  }
  const veiculo = await prepararMotoristaEVeiculo(await entrar(EMAIL_ADMIN, SENHA_ADMIN));
  const token = await entrar(MOTORISTA.email, MOTORISTA.senha);

  let viagem = await chamar('GET', '/viagens/atual', null, token);
  if (!viagem) viagem = await chamar('POST', '/viagens/iniciar', { veiculoId: veiculo._id, linha: LINHA, kmInicial: 1000 }, token);
  const viagemId = viagem._id || viagem.viagem?._id;
  console.log(`Viagem ${viagemId} em andamento (ônibus ${VEICULO.prefixo}, linha ${LINHA}). Abra a aba "Ao vivo" do painel.`);

  let encerrando = false;
  const encerrar = async () => {
    if (encerrando) return;
    encerrando = true;
    await chamar('POST', `/viagens/${viagemId}/encerrar`, { kmFinal: 1012, passageiros: 0, voltas: 1, ocorrencias: 'Viagem simulada' }, token);
    console.log('Viagem encerrada.');
    process.exit(0);
  };
  process.on('SIGINT', encerrar);

  const fim = Date.now() + Number(MINUTOS) * 60000;
  for (let passo = 0; Date.now() < fim; passo++) {
    const p = posicao(passo);
    await chamar('POST', '/localizacao', { viagemId, posicoes: [p] }, token);
    process.stdout.write(`\rposição ${passo + 1}: ${p.latitude.toFixed(5)}, ${p.longitude.toFixed(5)}   `);
    await new Promise(r => setTimeout(r, INTERVALO_MS));
  }
  console.log();
  await encerrar();
}

principal().catch(erro => {
  console.error(`\nErro: ${erro.message}`);
  process.exit(1);
});
