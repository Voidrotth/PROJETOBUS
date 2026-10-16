// Lê um arquivo enviado (HTML do Smart Report ou planilha CSV) e devolve os registros já no modelo
// único (modelosRelatorios.js), validados linha a linha. Não grava nada e não altera o arquivo.
//
// HTML -> documentos/tabelas -> identificar tipo (assinatura das colunas; se falhar, IA) -> extrair
//      -> normalizar -> validar (obrigatórios, tipos, duplicados) -> registros
const { MODELOS, NAO_CUMPRIDAS } = require('./modelosRelatorios');

class ErroLeitura extends Error {}

const MESES = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const DIAS_SEMANA = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
const MAX_ERROS = 5;

// ==================== HTML ====================

// Os relatórios vêm em Cp1252; planilhas costumam vir em UTF-8
function decodificar(bytes) {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes).replace(/^﻿/, '');
  } catch {
    return new TextDecoder('windows-1252').decode(bytes);
  }
}

const limpar = html => html
  .replace(/<br\s*\/?>/gi, ' ')
  .replace(/<[^>]+>/g, '')
  .replace(/&nbsp;/g, ' ').replace(/&quot;/g, '"').replace(/&gt;/g, '>').replace(/&lt;/g, '<').replace(/&amp;/g, '&')
  .replace(/\s+/g, ' ')
  .trim();

// Cada arquivo traz vários <html> colados; o título (<h1>, ou <title>) vale para as tabelas seguintes
function lerTabelas(html) {
  const tabelas = [];
  let titulo = '';
  for (const m of html.matchAll(/<title>([\s\S]*?)<\/title>|<h1>([\s\S]*?)<\/h1>|<table[^>]*>([\s\S]*?)<\/table>/gi)) {
    if (m[1] !== undefined || m[2] !== undefined) {
      titulo = limpar(m[1] ?? m[2]) || titulo;
      continue;
    }
    const colunas = [...m[3].matchAll(/<th[^>]*>([\s\S]*?)<\/th>/gi)].map(c => limpar(c[1]));
    if (!colunas.length) continue;
    const linhas = [...m[3].matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gi)]
      .map(tr => [...tr[1].matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gi)].map(td => limpar(td[1])))
      .filter(celulas => celulas.length);
    tabelas.push({ titulo, colunas, linhas });
  }
  return tabelas;
}

// ==================== CONVERSÃO ====================

const normalizarColuna = texto => texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
const dois = n => String(n).padStart(2, '0');

// Ponto = milhar, vírgula = decimal ("8543,6", "24.140", "20.434.667,35"): nenhum relatório usa ponto decimal
function numero(texto) {
  const valor = Number(texto.replace(/\./g, '').replace(',', '.'));
  if (!/^-?[\d.]+(,\d+)?$/.test(texto) || !Number.isFinite(valor)) throw new ErroLeitura(`número inválido "${texto}"`);
  return valor;
}

function dataValida(ano, mes, dia) {
  const d = new Date(Date.UTC(ano, mes - 1, dia));
  return d.getUTCFullYear() === ano && d.getUTCMonth() === mes - 1 && d.getUTCDate() === dia;
}

const CONVERSORES = {
  texto: v => v,
  inteiro: v => {
    const n = numero(v);
    if (!Number.isInteger(n)) throw new ErroLeitura(`esperava inteiro, veio "${v}"`);
    return n;
  },
  decimal: numero,
  data: v => {
    const m = v.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
    if (!m || !dataValida(+m[3], +m[2], +m[1])) throw new ErroLeitura(`data inválida "${v}"`);
    return `${m[3]}-${m[2]}-${m[1]}`;
  },
  mes: v => {
    if (!/^\d{4}-\d{2}$/.test(v)) throw new ErroLeitura(`mês inválido "${v}"`);
    return v;
  },
  dia: v => {
    if (!/^\d{1,2}$/.test(v)) throw new ErroLeitura(`dia inválido "${v}"`);
    return dois(v);
  },
  // Horários da operação são locais (São Paulo, sem horário de verão desde 2019)
  datahora: v => {
    const m = v.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/);
    if (!m || !dataValida(+m[1], +m[2], +m[3])) throw new ErroLeitura(`data/hora inválida "${v}"`);
    return new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6] || '00'}-03:00`);
  },
  faixa: v => {
    const m = v.match(/^(\d{1,2})(hs?)?$/i);
    if (!m || +m[1] > 23) throw new ErroLeitura(`faixa horária inválida "${v}"`);
    return +m[1];
  }
};

// "04/08/2026 14:37" ou "04-Ago 14:37" (sem ano: vem do último mês com dados no próprio arquivo)
function lerGeradoEm(texto, ultimaData) {
  let m = texto.match(/^(\d{2})\/(\d{2})\/(\d{4}) (\d{2}:\d{2})$/);
  if (m) return `${m[3]}-${m[2]}-${m[1]}T${m[4]}`;
  m = texto.match(/^(\d{2})-(\w{3}) (\d{2}:\d{2})$/);
  const mes = m ? MESES.indexOf(m[2].toLowerCase()) + 1 : 0;
  if (!m || !mes || !ultimaData) throw new ErroLeitura(`horário de geração inesperado "${texto}"`);
  // Relatório de dezembro gerado em janeiro: o ano vira
  const ano = +ultimaData.slice(0, 4) + (mes < +ultimaData.slice(5, 7) ? 1 : 0);
  return `${ano}-${dois(mes)}-${m[1]}T${m[3]}`;
}

// ==================== IDENTIFICAÇÃO ====================

// Assinatura: todas as colunas do modelo presentes (sem acento/caixa/espaço). Se mais de um modelo
// servir (não realizadas/iniciadas/terminadas têm as mesmas colunas), o título decide.
function identificarPorAssinatura(tabela) {
  const posicao = Object.fromEntries(tabela.colunas.map((c, i) => [normalizarColuna(c), i]));
  const candidatos = Object.entries(MODELOS).filter(([, modelo]) =>
    Object.values(modelo.campos).every(([coluna]) => normalizarColuna(coluna) in posicao));
  const escolhido = candidatos.length === 1 ? candidatos[0] : candidatos.find(([, m]) => m.titulo.test(tabela.titulo));
  if (!escolhido) return null;
  const [tipo, modelo] = escolhido;
  // Um modelo menor pode caber dentro de um maior (Resumo por Faixa ⊂ Partidas por Faixa): exige o título
  // quando sobram colunas que o modelo não usa
  const usadas = Object.keys(modelo.campos).length;
  if (usadas < tabela.colunas.length && !modelo.titulo.test(tabela.titulo)) return null;
  const mapa = Object.fromEntries(Object.entries(modelo.campos).map(([campo, [coluna]]) => [campo, tabela.colunas[posicao[normalizarColuna(coluna)]]]));
  return { tipo, mapa, identificacao: 'assinatura' };
}

// Confere a resposta da IA antes de usar: tipo existe, colunas existem, obrigatórios mapeados, sem coluna repetida
function validarMapaIA(resposta, tabela) {
  const modelo = MODELOS[resposta?.tipo];
  if (!modelo) throw new ErroLeitura(`a IA respondeu um tipo desconhecido (${resposta?.tipo})`);
  const mapa = resposta.mapa || {};
  for (const [campo, coluna] of Object.entries(mapa)) {
    if (!(campo in modelo.campos)) throw new ErroLeitura(`a IA mapeou um campo que não existe em ${resposta.tipo}: ${campo}`);
    if (coluna != null && !tabela.colunas.includes(coluna)) throw new ErroLeitura(`a IA citou uma coluna que não existe: "${coluna}"`);
  }
  const faltando = Object.entries(modelo.campos).filter(([campo, [, , obrigatorio]]) => obrigatorio && !mapa[campo]).map(([c]) => c);
  if (faltando.length) throw new ErroLeitura(`a IA não encontrou colunas para ${faltando.join(', ')} (${resposta.tipo})`);
  const colunas = Object.values(mapa).filter(Boolean);
  if (new Set(colunas).size !== colunas.length) throw new ErroLeitura('a IA usou a mesma coluna para dois campos');
  return { tipo: resposta.tipo, mapa: Object.fromEntries(Object.entries(mapa).filter(([, c]) => c)), identificacao: 'ia' };
}

// ==================== EXTRAÇÃO E VALIDAÇÃO ====================

const CHAVES = {
  resumoGeral: r => r.data,
  cumprimento: r => r.data,
  resumoLinha: r => `${r.data}|${r.linha}`,
  partidasFaixa: r => `${r.data}|${r.linha}|${r.hora}`,
  resumoFaixa: r => `${r.data}|${r.hora}`,
  viagens: r => `${r.data}|${r.prefixo}|${r.atividade}|${r.inicio?.toISOString() ?? ''}`,
  passageiros: r => r.data,
  saldo: r => r.data,
  creditos: r => r.data,
  ...Object.fromEntries(Object.keys(NAO_CUMPRIDAS).map(t => [t, r => `${r.data}|${r.linha}|${r.tabela}|${r.inicioProgramado.toISOString()}`]))
};

const SENTIDOS = { I: 'ida', V: 'volta' };
const ATIVIDADES = { 'viagem normal': 'normal', improdutivas: 'improdutiva' };

// Ajustes do formato de origem para o modelo (e obrigatórios que dependem de outro campo)
function normalizarRegistro(tipo, r) {
  if (r.linha) r.linha = r.linha.padStart(2, '0');
  if (r.sentido) {
    if (!SENTIDOS[r.sentido]) throw new ErroLeitura(`sentido inválido "${r.sentido}"`);
    r.sentido = SENTIDOS[r.sentido];
  }
  if (tipo === 'viagens') {
    const atividade = ATIVIDADES[r.atividade.toLowerCase()];
    if (!atividade) throw new ErroLeitura(`atividade desconhecida "${r.atividade}"`);
    r.atividade = atividade;
    if (atividade === 'normal') {
      const faltando = ['linha', 'sentido', 'inicio', 'fim'].filter(c => r[c] == null);
      if (faltando.length) throw new ErroLeitura(`viagem normal sem ${faltando.join(', ')}`);
    }
  }
  if (tipo in NAO_CUMPRIDAS) r.tipo = NAO_CUMPRIDAS[tipo];
  if (tipo === 'resumoGeral' && !DIAS_SEMANA.includes(r.diaSemana)) throw new ErroLeitura(`dia da semana inválido "${r.diaSemana}"`);
  return r;
}

// Linha de total: sem data (operação) ou com "Total Mês" no lugar do dia (bilhetagem)
function ehTotal(modelo, celula) {
  if ('data' in modelo.campos) return !/^\d{2}\/\d{2}\/\d{4}$/.test(celula('data'));
  return !/^\d{1,2}$/.test(celula('dia'));
}

function extrair(tipo, mapa, tabela) {
  const modelo = MODELOS[tipo];
  const indice = Object.fromEntries(Object.entries(mapa).map(([campo, coluna]) => [campo, tabela.colunas.indexOf(coluna)]));
  const registros = [];
  const totais = [];
  const erros = [];
  const vistos = new Set();

  tabela.linhas.forEach((celulas, n) => {
    const celula = campo => (indice[campo] >= 0 ? (celulas[indice[campo]] ?? '').trim() : '');
    const total = ehTotal(modelo, celula);
    try {
      const r = {};
      for (const [campo, [, tipoCampo, obrigatorio]] of Object.entries(modelo.campos)) {
        const valor = celula(campo);
        if (valor === '') {
          if (obrigatorio && !total) throw new ErroLeitura(`campo obrigatório vazio: ${campo}`);
          r[campo] = null;
        } else if (total && ['data', 'dia', 'datahora'].includes(tipoCampo)) {
          r[campo] = valor; // rótulo da linha de total ("Total Geral", "Total Mês")
        } else {
          r[campo] = CONVERSORES[tipoCampo](valor);
        }
      }
      if (total) return totais.push(r);
      if (r.mes) {
        if (!dataValida(+r.mes.slice(0, 4), +r.mes.slice(5), +r.dia)) throw new ErroLeitura(`data inválida ${r.mes}-${r.dia}`);
        r.data = `${r.mes}-${r.dia}`;
        delete r.mes;
        delete r.dia;
      }
      normalizarRegistro(tipo, r);
      const chave = CHAVES[tipo](r);
      if (vistos.has(chave)) throw new ErroLeitura(`registro duplicado (${chave})`);
      vistos.add(chave);
      registros.push(r);
    } catch (erro) {
      if (!(erro instanceof ErroLeitura)) throw erro;
      if (erros.length < MAX_ERROS) erros.push(`linha ${n + 1}: ${erro.message}`);
      else erros.excedente = (erros.excedente || 0) + 1;
    }
  });
  if (erros.length) {
    throw new ErroLeitura(`"${tabela.titulo}": ${erros.join('; ')}${erros.excedente ? ` (e mais ${erros.excedente})` : ''}`);
  }
  return { registros, totais };
}

// ==================== ARQUIVO ====================

const ehCabecalhoDeGeracao = t => t.colunas.length === 2 && t.colunas[1] === 'Horário' && t.linhas.length;

/**
 * Lê um HTML do Smart Report.
 * identificarComIA(tabela) -> { tipo, mapa } é chamada só para tabelas que a assinatura não reconhece.
 */
async function lerHtml(nome, bytes, identificarComIA) {
  const tabelas = lerTabelas(decodificar(bytes));
  const geracao = tabelas.find(ehCabecalhoDeGeracao);
  const relatorios = [];
  const naoReconhecidas = [];

  for (const tabela of tabelas) {
    if (tabela === geracao) continue;
    let identificado = identificarPorAssinatura(tabela);
    let respostaIA = null;
    if (!identificado && identificarComIA) {
      try {
        respostaIA = await identificarComIA(tabela);
        identificado = validarMapaIA(respostaIA, tabela);
      } catch (erro) {
        throw new ErroLeitura(`"${tabela.titulo || tabela.colunas.join(', ')}" não foi reconhecida: ${erro.message}`);
      }
    }
    if (!identificado) {
      naoReconhecidas.push(tabela.titulo || tabela.colunas.join(', '));
      continue;
    }
    let extraido;
    try {
      extraido = extrair(identificado.tipo, identificado.mapa, tabela);
    } catch (erro) {
      // Mapa da IA que não converte os dados é recusado, não adivinhado
      if (identificado.identificacao === 'ia') erro.message = `mapa de colunas sugerido pela IA não serve: ${erro.message}`;
      throw erro;
    }
    // Só depois de validado e extraído o mapa da IA é guardado para as próximas leituras
    await respostaIA?.guardar?.();
    relatorios.push({
      ...identificado,
      titulo: tabela.titulo,
      periodicidade: tabela.titulo.match(/^(Mensal|Quinzenal)\b/i)?.[1] || null,
      ...extraido
    });
  }

  if (!relatorios.length) {
    throw new ErroLeitura(naoReconhecidas.length
      ? `nenhum relatório reconhecido (${naoReconhecidas.join('; ')})`
      : 'nenhuma tabela encontrada');
  }
  const datas = relatorios.flatMap(r => r.registros.map(x => x.data)).sort();
  return {
    arquivo: nome,
    geradoEm: geracao ? lerGeradoEm(geracao.linhas[0][1], datas.at(-1)) : null,
    inicio: datas[0] || null,
    fim: datas.at(-1) || null,
    relatorios,
    naoReconhecidas
  };
}

// ==================== PLANILHA CSV ====================
// Primeira coluna "data" (dd/mm/aaaa ou aaaa-mm-dd); as outras com o nome de um campo do painel.
// Com ";" os números seguem o padrão brasileiro (1.234,56); com "," usam ponto decimal (1234.56).

function lerCsv(nome, bytes, camposAceitos) {
  const linhas = decodificar(bytes).split(/\r?\n/).filter(l => l.trim());
  if (!linhas.length) throw new ErroLeitura('planilha vazia');
  const separador = linhas[0].includes(';') ? ';' : ',';
  const [primeira, ...campos] = linhas[0].split(separador).map(c => c.trim());
  if (primeira.toLowerCase() !== 'data') throw new ErroLeitura('a primeira coluna da planilha precisa se chamar "data"');
  const desconhecida = campos.find(c => !camposAceitos.includes(c));
  if (desconhecida) throw new ErroLeitura(`coluna desconhecida "${desconhecida}". Colunas aceitas: ${camposAceitos.join(', ')}`);

  const registros = linhas.slice(1).map((linha, n) => {
    const [data, ...celulas] = linha.split(separador).map(c => c.trim());
    const iso = /^\d{4}-\d{2}-\d{2}$/.test(data) ? data : /^\d{2}\/\d{2}\/\d{4}$/.test(data) ? data.split('/').reverse().join('-') : null;
    if (!iso || !dataValida(+iso.slice(0, 4), +iso.slice(5, 7), +iso.slice(8))) throw new ErroLeitura(`linha ${n + 2}: data inválida "${data}"`);
    const registro = { data: iso };
    campos.forEach((campo, i) => {
      const celula = celulas[i] ?? '';
      if (!celula) return;
      const valor = separador === ';' ? numero(celula) : Number(celula);
      if (!Number.isFinite(valor)) throw new ErroLeitura(`linha ${n + 2}: valor inválido "${celula}" em ${campo}`);
      registro[campo] = valor;
    });
    return registro;
  });
  const datas = registros.map(r => r.data).sort();
  return {
    arquivo: nome,
    geradoEm: null,
    inicio: datas[0] || null,
    fim: datas.at(-1) || null,
    relatorios: [{ tipo: 'planilha', titulo: `Planilha (${campos.join(', ')})`, identificacao: 'planilha', registros, totais: [] }],
    naoReconhecidas: []
  };
}

module.exports = { lerHtml, lerCsv, lerTabelas, decodificar, normalizarColuna, ErroLeitura, DIAS_SEMANA };
