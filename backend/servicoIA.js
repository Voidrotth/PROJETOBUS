const OpenAI = require('openai');
const { MODELOS } = require('./modelosRelatorios');
const MapeamentoIA = require('./MapeamentoIA');

// OpenRouter usa a mesma API da OpenAI, só muda o endereço e o nome do modelo
const openai = new OpenAI({
  baseURL: 'https://openrouter.ai/api/v1',
  apiKey: process.env.OPENROUTER_API_KEY || 'chave-nao-configurada',
  defaultHeaders: {
    'HTTP-Referer': 'http://localhost:3000',
    'X-Title': 'PROJETOBUS'
  }
});

// Modelos gratuitos do OpenRouter mudam com frequência: se der 404/429, troque IA_MODELO no .env
const MODELO_IA = process.env.IA_MODELO || 'nvidia/nemotron-3-super-120b-a12b:free';
const LINHAS_AMOSTRA = 5;

// Catálogo em texto para a IA: os tipos e campos que o sistema conhece (docs/ANALISE_DADOS.md)
const CATALOGO = Object.entries(MODELOS).map(([tipo, modelo]) =>
  `- ${tipo}: ${modelo.descricao}\n` +
  Object.entries(modelo.campos).map(([campo, [coluna, formato, obrigatorio, descricao]]) =>
    `    ${campo} (${formato}${obrigatorio ? ', obrigatório' : ''}): ${descricao}; costuma vir na coluna "${coluna}"`).join('\n')
).join('\n');

// A mesma tabela (título + colunas) só vai para a IA uma vez: o mapa aceito fica guardado
const assinatura = tabela => `${tabela.titulo}|${tabela.colunas.join('|')}`;

/**
 * Pede à IA o tipo de relatório e o mapa campo -> coluna de uma tabela que a assinatura não reconheceu.
 * Recebe só título, colunas e algumas linhas (o arquivo de viagens inteiro passa de 10 MB).
 * Quem chama valida a resposta (leitorRelatorios.validarMapaIA) antes de usar.
 */
async function identificarTabela(tabela) {
  const chave = assinatura(tabela);
  const guardado = await MapeamentoIA.findOne({ assinatura: chave }).lean();
  if (guardado) return { tipo: guardado.tipo, mapa: guardado.mapa };

  if (!process.env.OPENROUTER_API_KEY) throw new Error('layout desconhecido e a IA não está configurada (OPENROUTER_API_KEY)');

  const instrucao = `Você identifica relatórios de operação de ônibus. Abaixo está uma tabela extraída de um HTML
e o catálogo dos tipos de relatório conhecidos. Diga qual tipo ela é e qual coluna da tabela corresponde a cada campo.
As colunas podem ter nomes diferentes dos usuais; use o significado e os valores da amostra.

CATÁLOGO
${CATALOGO}

TABELA
Título: ${tabela.titulo || '(sem título)'}
Colunas: ${JSON.stringify(tabela.colunas)}
Amostra: ${JSON.stringify(tabela.linhas.slice(0, LINHAS_AMOSTRA))}

Responda APENAS com JSON no formato:
{"tipo": "<um tipo do catálogo ou null se nenhum servir>", "mapa": {"<campo>": "<nome exato da coluna>"}}
Use o nome exato da coluna como está em "Colunas". Não invente colunas. Campo sem coluna correspondente fica de fora.`;

  const requisicao = {
    model: MODELO_IA,
    messages: [{ role: 'user', content: instrucao }],
    temperature: 0
  };
  // Modelos gratuitos (:free) do OpenRouter geralmente não aceitam response_format
  if (!MODELO_IA.endsWith(':free')) requisicao.response_format = { type: 'json_object' };

  const resposta = await openai.chat.completions.create(requisicao);
  const json = extrairJson(resposta.choices[0].message.content || '');
  if (!json.tipo) throw new Error('a IA não reconheceu a tabela como nenhum relatório do catálogo');
  return { ...json, guardar: () => MapeamentoIA.updateOne({ assinatura: chave }, { tipo: json.tipo, mapa: json.mapa, modelo: MODELO_IA }, { upsert: true }) };
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

module.exports = { identificarTabela };
