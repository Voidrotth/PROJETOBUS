const OpenAI = require('openai');

// OpenRouter usa a mesma API da OpenAI, só muda o endereço e o nome do modelo
const openai = new OpenAI({
  baseURL: 'https://openrouter.ai/api/v1',
  apiKey: process.env.OPENROUTER_API_KEY || 'chave-nao-configurada',
  defaultHeaders: {
    'HTTP-Referer': 'http://localhost:3000',
    'X-Title': 'PROJETOBUS'
  }
});

const MODELO_IA = process.env.IA_MODELO || 'inclusionai/ling-3.0-flash-vl:free';

/**
 * Interpreta o texto de um e-mail e extrai dados operacionais de ônibus.
 * Retorna um objeto JSON com os campos estruturados.
 */
async function interpretarTextoEmail(texto) {
  const instrucao = `Você é um assistente que extrai dados operacionais de ônibus a partir de texto de e-mail.

Extraia os seguintes campos do texto abaixo. Retorne APENAS um JSON válido com os campos encontrados.
Se um campo não for encontrado no texto, use null.

Campos:
- linha (String): número ou nome da linha de ônibus
- veiculo (String): placa ou prefixo do veículo
- motorista (String): nome do motorista
- cobrador (String): nome do cobrador
- dataOperacao (String): data da operação no formato YYYY-MM-DD
- horarioSaida (String): horário de saída no formato HH:MM
- horarioRecolhimento (String): horário de recolhimento no formato HH:MM
- kmInicial (Number): quilometragem inicial
- kmFinal (Number): quilometragem final
- passageiros (Number): quantidade de passageiros
- viagens (Number): número de viagens realizadas
- ocorrencias (String): ocorrências durante a operação

Texto do e-mail:
${texto}

Responda APENAS com o JSON, sem explicações.`;

  const requisicao = {
    model: MODELO_IA,
    messages: [{ role: 'user', content: instrucao }],
    temperature: 0.1
  };
  // Modelos gratuitos (:free) do OpenRouter geralmente não aceitam response_format
  if (!MODELO_IA.endsWith(':free')) {
    requisicao.response_format = { type: 'json_object' };
  }

  const resposta = await openai.chat.completions.create(requisicao);
  return extrairJson(resposta.choices[0].message.content || '');
}

// Pega o JSON da resposta, mesmo que venha dentro de ```json ... ``` ou com texto em volta
function extrairJson(conteudo) {
  const inicio = conteudo.indexOf('{');
  const fim = conteudo.lastIndexOf('}');
  if (inicio === -1 || fim <= inicio) {
    throw new Error(`IA não retornou JSON: ${conteudo.slice(0, 200)}`);
  }
  return JSON.parse(conteudo.slice(inicio, fim + 1));
}

module.exports = { interpretarTextoEmail };
