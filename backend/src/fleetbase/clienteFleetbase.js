// Cliente HTTP da API pública do Fleetbase (/v1). Só este arquivo conhece URL e chave.
const URL_BASE = (process.env.FLEETBASE_URL || 'http://localhost:8000').replace(/\/+$/, '');
const CHAVE_API = process.env.FLEETBASE_API_KEY || '';
const TEMPO_LIMITE_MS = 10000;

// Sem FLEETBASE_API_KEY no .env o sistema funciona normalmente, sem Fleetbase
const fleetbaseHabilitado = Boolean(CHAVE_API);

class ErroFleetbase extends Error {
  constructor(mensagem, status) {
    super(mensagem);
    this.status = status;
  }
}

async function requisitar(metodo, caminho, corpo) {
  let resposta;
  try {
    resposta = await fetch(`${URL_BASE}/v1/${caminho}`, {
      method: metodo,
      headers: {
        Authorization: `Bearer ${CHAVE_API}`,
        Accept: 'application/json',
        ...(corpo ? { 'Content-Type': 'application/json' } : {})
      },
      body: corpo ? JSON.stringify(corpo) : undefined,
      signal: AbortSignal.timeout(TEMPO_LIMITE_MS)
    });
  } catch (erro) {
    throw new ErroFleetbase(`Fleetbase inacessível (${erro.message})`, 0);
  }

  const texto = await resposta.text();
  let dados = null;
  try {
    dados = texto ? JSON.parse(texto) : null;
  } catch {
    dados = texto;
  }

  if (!resposta.ok) {
    const detalhe = dados?.errors?.join?.(', ') || dados?.error || dados?.message || texto.slice(0, 200);
    throw new ErroFleetbase(`Fleetbase ${metodo} /v1/${caminho} → ${resposta.status}: ${detalhe}`, resposta.status);
  }
  return dados;
}

module.exports = {
  fleetbaseHabilitado,
  ErroFleetbase,
  get: caminho => requisitar('GET', caminho),
  post: (caminho, corpo) => requisitar('POST', caminho, corpo),
  put: (caminho, corpo) => requisitar('PUT', caminho, corpo)
};
