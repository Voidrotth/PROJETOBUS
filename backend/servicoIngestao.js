// Lê a pasta de dados inteira (arquivos de dados/ e os enviados pelo painel), consolida, confere e grava.
//
// ARQUIVO -> leitorRelatorios (identificar, extrair, validar linha a linha) -> consolidar (emissão mais nova
// vence em cada dia) -> conferir relatórios entre si -> gravar no banco
// Relê tudo a cada chamada e deixa o banco igual à pasta (pode rodar quantas vezes quiser).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const IndicadorDiario = require('./IndicadorDiario');
const ImportacaoDados = require('./ImportacaoDados');
const ViagemRealizada = require('./ViagemRealizada');
const ViagemNaoCumprida = require('./ViagemNaoCumprida');
const { lerHtml, lerCsv, ErroLeitura, DIAS_SEMANA } = require('./leitorRelatorios');
const { NAO_CUMPRIDAS } = require('./modelosRelatorios');
const { identificarTabela } = require('./servicoIA');
const { ErroHttp } = require('./tratarErro');

const PASTA_DADOS = path.resolve(process.env.DADOS_PASTA || path.join(__dirname, '../esquecidos/dados'));
const TOLERANCIA = 0.051; // os relatórios arredondam km em 1 casa e R$ em 2
const LOTE = 5000;

// Grupos de indicadores diários: de qual relatório vêm e quais campos
const GRUPOS = {
  operacao: ['resumoGeral', ['veiculos', 'maxVeiculosFaixa', 'viagensProgramadas', 'viagensRealizadas', 'viagensNaoCumpridas', 'kmProdutiva', 'kmImprodutiva', 'kmTotal']],
  turnos: ['cumprimento', ['manhaProgramadas', 'manhaRealizadas', 'tardeProgramadas', 'tardeRealizadas', 'noiteProgramadas', 'noiteRealizadas']],
  passageiros: ['passageiros', ['catraca', 'antecipados', 'naoPagantes', 'passageiros']],
  creditos: ['creditos', ['vendas', 'utilizacao', 'circulante']],
  saldo: ['saldo', ['transferidos', 'saldoFinal']],
  // O Smart Report não traz a receita de catraca em R$: só chega por planilha CSV
  receita: [null, ['receitaCatracaDinheiro', 'receitaCatracaCartao']]
};
const CAMPOS_PLANILHA = Object.values(GRUPOS).flatMap(([, campos]) => campos);
const GRUPO_DO_CAMPO = Object.fromEntries(Object.entries(GRUPOS).flatMap(([grupo, [, campos]]) => campos.map(c => [c, grupo])));
const OPERACAO = new Set(['resumoGeral', 'cumprimento', 'resumoLinha', 'partidasFaixa', 'resumoFaixa', 'viagens', ...Object.keys(NAO_CUMPRIDAS)]);

const arredondar = v => Math.round(v * 100) / 100;
const igual = (a, b) => Math.abs(a - b) < TOLERANCIA;
const soma = (lista, campo) => arredondar(lista.reduce((s, r) => s + (r[campo] || 0), 0));
const agrupar = (lista, chave) => lista.reduce((m, r) => ((m[chave(r)] ??= []).push(r), m), {});
const somarDias = (data, n) => new Date(Date.parse(data) + n * 86400000).toISOString().slice(0, 10);
const diaDaSemana = data => DIAS_SEMANA[(new Date(`${data}T12:00:00Z`).getUTCDay() + 6) % 7];

// "B. BOA VISTA SENTIDO ESTAÇÃO" e "BAIRRO BOA VISTA SENTIDO ESTACAO" viram o mesmo itinerário
const itinerario = texto => texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase()
  .replace(/\bB\.\s*/g, 'BAIRRO ').replace(/\bCIRC\.(?=\s|$)/g, 'CIRCULAR').replace(/\s+/g, ' ').trim();

// ==================== LEITURA ====================

function listar(pasta) {
  if (!fs.existsSync(pasta)) return [];
  return fs.readdirSync(pasta, { recursive: true })
    .filter(nome => /\.(html?|csv)$/i.test(nome))
    .map(nome => nome.split(path.sep).join('/'))
    .sort();
}

async function lerArquivos() {
  const lidos = [];
  const recusados = [];
  const vistos = new Set();
  for (const arquivo of listar(PASTA_DADOS)) {
    const bytes = fs.readFileSync(path.join(PASTA_DADOS, arquivo));
    const recusar = (uso, erro) => recusados.push({ arquivo, relatorios: [], registros: 0, geradoEm: null, inicio: null, fim: null, uso, erro });
    // O mesmo arquivo enviado de novo entra uma vez só
    const hash = crypto.createHash('sha1').update(bytes).digest('hex');
    if (vistos.has(hash)) { recusar('duplicado'); continue; }
    vistos.add(hash);
    try {
      lidos.push(/\.csv$/i.test(arquivo)
        ? lerCsv(arquivo, bytes, CAMPOS_PLANILHA)
        : await lerHtml(arquivo, bytes, identificarTabela));
    } catch (erro) {
      if (!(erro instanceof ErroLeitura)) throw erro;
      recusar('erro', erro.message);
    }
  }
  // Emissão mais antiga primeiro (a mais nova sobrescreve); planilhas do gestor por último
  lidos.sort((a, b) => (a.geradoEm === null) - (b.geradoEm === null) ||
    String(a.geradoEm).localeCompare(String(b.geradoEm)) || a.arquivo.localeCompare(b.arquivo));
  return { lidos, recusados };
}

// ==================== CONSOLIDAÇÃO ====================

// Um registro por data com a versão mais recente de cada grupo; diferenças entre emissões viram revisões
function consolidarDias(lidos) {
  const porData = {};
  const diaDe = data => (porData[data] ??= { data, fontes: {}, revisoes: [] });
  const gravar = (dia, campo, valor, grupo, arquivo) => {
    if (dia.fontes[grupo] && dia[campo] !== valor) {
      dia.revisoes.push({ campo, de: dia[campo] ?? null, para: valor ?? null, arquivoAnterior: dia.fontes[grupo], arquivo });
    }
    dia[campo] = valor;
  };
  for (const lido of lidos) {
    for (const rel of lido.relatorios) {
      if (rel.tipo === 'planilha') {
        for (const r of rel.registros) {
          const dia = diaDe(r.data);
          for (const campo of Object.keys(r).filter(c => c !== 'data')) gravar(dia, campo, r[campo], 'planilha', lido.arquivo);
          dia.fontes.planilha = lido.arquivo;
        }
        continue;
      }
      const grupo = Object.keys(GRUPOS).find(g => GRUPOS[g][0] === rel.tipo);
      if (!grupo) continue;
      for (const r of rel.registros) {
        const dia = diaDe(r.data);
        for (const campo of GRUPOS[grupo][1]) gravar(dia, campo, r[campo], grupo, lido.arquivo);
        dia.fontes[grupo] = lido.arquivo;
      }
    }
  }
  const dias = Object.values(porData).sort((a, b) => a.data.localeCompare(b.data));
  classificarDias(dias);
  return dias;
}

// Seg–Sex com menos viagens programadas que a programação mais comum dos Seg–Sex vizinhos (±7 dias).
// Os relatórios não trazem feriado: a marca só sugere ao gestor quais dias cadastrar.
function classificarDias(dias) {
  const uteis = dias.filter(d => d.viagensProgramadas != null && DIAS_SEMANA.indexOf(diaDaSemana(d.data)) < 5);
  for (const dia of dias) {
    dia.diaSemana = diaDaSemana(dia.data);
    dia.programacaoReduzida = false;
    if (DIAS_SEMANA.indexOf(dia.diaSemana) >= 5 || dia.viagensProgramadas == null) continue;
    const contagem = {};
    for (const v of uteis) {
      if (v.data >= somarDias(dia.data, -7) && v.data <= somarDias(dia.data, 7)) contagem[v.viagensProgramadas] = (contagem[v.viagensProgramadas] || 0) + 1;
    }
    const [maisComum] = Object.entries(contagem).sort((a, b) => b[1] - a[1] || b[0] - a[0])[0];
    dia.programacaoReduzida = dia.viagensProgramadas < Number(maisComum);
  }
}

// Relatórios de operação agrupados por emissão (mesmo horário de geração): é assim que se cruzam
function emissoesDeOperacao(lidos) {
  const emissoes = {};
  for (const lido of lidos) {
    for (const rel of lido.relatorios) {
      if (!OPERACAO.has(rel.tipo)) continue;
      const e = (emissoes[lido.geradoEm ?? lido.arquivo] ??= { geradoEm: lido.geradoEm, relatorios: {}, arquivos: {}, dias: new Set() });
      (e.relatorios[rel.tipo] ??= []).push(...rel.registros);
      e.arquivos[rel.tipo] = lido.arquivo;
      rel.registros.forEach(r => e.dias.add(r.data));
    }
  }
  // Mais antiga primeiro
  return Object.values(emissoes).sort((a, b) => String(a.geradoEm).localeCompare(String(b.geradoEm)));
}

// Para cada dia, as viagens e as não cumpridas da emissão mais nova que cobre o dia.
// O conjunto do dia é trocado inteiro: viagem que sumiu numa revisão também sai.
function consolidarViagens(emissoes) {
  const viagens = {};
  const naoCumpridas = {};
  for (const e of emissoes) {
    if (e.relatorios.viagens) {
      for (const [data, doDia] of Object.entries(agrupar(e.relatorios.viagens, r => r.data))) {
        viagens[data] = doDia.map(r => ({ ...r, fonte: e.arquivos.viagens }));
      }
    }
    const tiposNc = Object.keys(NAO_CUMPRIDAS).filter(t => e.relatorios[t]);
    if (!tiposNc.length) continue;
    // Relatório de não cumpridas vazio também vale: significa "nenhuma" nos dias da emissão
    const ncDoDia = agrupar(tiposNc.flatMap(t => e.relatorios[t].map(r => ({ ...r, fonte: e.arquivos[t] }))), r => r.data);
    for (const data of e.dias) naoCumpridas[data] = (ncDoDia[data] || []).map(r => ({ ...r, itinerario: itinerario(r.atendimento) }));
  }
  return { viagens, naoCumpridas };
}

// ==================== CONFERÊNCIAS ====================
// Não bloqueiam a gravação (os relatórios são oficiais); ficam registradas e aparecem no painel

function conferir(lidos, emissoes, dias) {
  const conferencias = [];
  const add = (descricao, itens) => conferencias.push({
    descricao,
    verificados: itens.length,
    divergencias: itens.filter(i => !i.ok).map(({ ok, ...resto }) => resto)
  });
  const relatoriosDo = tipo => lidos.flatMap(l => l.relatorios.filter(r => r.tipo === tipo).map(r => ({ ...r, arquivo: l.arquivo })));
  const registrosDo = tipo => relatoriosDo(tipo).flatMap(r => r.registros.map(x => ({ ...x, arquivo: r.arquivo })));

  // ---- Dentro de cada relatório
  const resumos = registrosDo('resumoGeral');
  add('Operação: kmProd + kmImprod = kmTotal (por dia)', resumos.map(d => ({
    ok: igual(d.kmProdutiva + d.kmImprodutiva, d.kmTotal), data: d.data, arquivo: d.arquivo,
    detalhe: `${d.kmProdutiva} + ${d.kmImprodutiva} ≠ ${d.kmTotal}`
  })));
  add('Operação: programadas − realizadas = Dif Viagens (por dia)', resumos.map(d => ({
    ok: d.viagensProgramadas - d.viagensRealizadas === d.viagensNaoCumpridas, data: d.data, arquivo: d.arquivo,
    detalhe: `${d.viagensProgramadas} − ${d.viagensRealizadas} ≠ ${d.viagensNaoCumpridas}`
  })));
  add('Operação: dia da semana do relatório = dia da semana da data', resumos.map(d => ({
    ok: diaDaSemana(d.data) === d.diaSemana, data: d.data, arquivo: d.arquivo, detalhe: `relatório diz ${d.diaSemana}`
  })));
  add('Turnos: manhã + tarde + noite = total do dia', registrosDo('cumprimento').map(d => ({
    ok: d.manhaProgramadas + d.tardeProgramadas + d.noiteProgramadas === d.programadas &&
      d.manhaRealizadas + d.tardeRealizadas + d.noiteRealizadas === d.realizadas,
    data: d.data, arquivo: d.arquivo, detalhe: `turnos não somam ${d.programadas}/${d.realizadas}`
  })));
  add('Viagens: fim depois do início (viagens normais)', registrosDo('viagens').filter(v => v.atividade === 'normal').map(v => ({
    ok: v.fim > v.inicio, data: v.data, arquivo: v.arquivo, detalhe: `prefixo ${v.prefixo} linha ${v.linha}: fim antes do início`
  })));
  add('Passageiros: Catraca + Antecipados + Não Pagantes = Total (por dia)', registrosDo('passageiros').map(d => ({
    ok: d.catraca + d.antecipados + d.naoPagantes === d.passageiros, data: d.data, arquivo: d.arquivo,
    detalhe: `${d.catraca} + ${d.antecipados} + ${d.naoPagantes} ≠ ${d.passageiros}`
  })));
  add('Créditos: Total Vendas − Total Utilização = Crédito Circulante (por dia)', registrosDo('creditos').map(d => ({
    ok: igual(d.vendas - d.utilizacao, d.circulante), data: d.data, arquivo: d.arquivo,
    detalhe: `${d.vendas} − ${d.utilizacao} ≠ ${d.circulante}`
  })));

  // Soma das linhas = linha de total do próprio relatório
  const SOMAS = {
    resumoGeral: ['viagensProgramadas', 'viagensRealizadas', 'viagensNaoCumpridas', 'kmProdutiva', 'kmImprodutiva', 'kmTotal'],
    cumprimento: ['programadas', 'realizadas'],
    resumoLinha: ['kmProdutiva', 'viagens'],
    partidasFaixa: ['viagens'],
    resumoFaixa: ['viagens'],
    viagens: ['kmProdutiva', 'kmImprodutiva', 'kmTotal'],
    passageiros: ['catraca', 'antecipados', 'naoPagantes', 'passageiros'],
    creditos: ['vendas', 'utilizacao', 'circulante'],
    saldo: ['transferidos']
  };
  add('Soma das linhas = linha de total (por relatório)', Object.entries(SOMAS).flatMap(([tipo, campos]) =>
    relatoriosDo(tipo).flatMap(rel => rel.totais.flatMap(total => campos.filter(c => total[c] != null).map(campo => {
      // Bilhetagem: um "Total Mês" por mês e, às vezes, um "Total Acumulado" sem mês
      const doTotal = total.mes ? rel.registros.filter(r => r.data.startsWith(total.mes)) : rel.registros;
      const somado = soma(doTotal, campo);
      return { ok: igual(somado, total[campo]), arquivo: rel.arquivo, detalhe: `${rel.titulo} ${total.mes || ''} ${campo}: soma ${somado} ≠ total ${total[campo]}` };
    })))));

  // ---- Entre relatórios da mesma emissão (docs/ANALISE_DADOS.md, seção 4)
  for (const e of emissoes) {
    const R = e.relatorios;
    const rotulo = `emissão ${e.geradoEm || '?'}`;
    const resumoDia = Object.fromEntries((R.resumoGeral || []).map(r => [r.data, r]));
    const normais = (R.viagens || []).filter(v => v.atividade === 'normal');
    const porDia = agrupar(R.viagens || [], v => v.data);
    const normaisPorDia = agrupar(normais, v => v.data);
    const distintos = (lista, campo) => new Set(lista.map(v => v[campo])).size;

    if (R.viagens && R.resumoGeral) {
      add(`Viagens (uma a uma) × Resumo Geral: viagens, km e veículos do dia (${rotulo})`, R.resumoGeral.map(r => {
        const doDia = porDia[r.data] || [];
        const normaisDia = normaisPorDia[r.data] || [];
        return {
          ok: normaisDia.length === r.viagensRealizadas && igual(soma(doDia, 'kmProdutiva'), r.kmProdutiva) &&
            igual(soma(doDia, 'kmImprodutiva'), r.kmImprodutiva) && distintos(normaisDia, 'prefixo') === r.veiculos,
          data: r.data, arquivo: e.arquivos.viagens,
          detalhe: `viagens ${normaisDia.length}/${r.viagensRealizadas}, kmProd ${soma(doDia, 'kmProdutiva')}/${r.kmProdutiva}, ` +
            `kmImprod ${soma(doDia, 'kmImprodutiva')}/${r.kmImprodutiva}, veículos ${distintos(normaisDia, 'prefixo')}/${r.veiculos}`
        };
      }));
    }
    if (R.viagens && R.resumoLinha) {
      const porLinha = agrupar(normais, v => `${v.data}|${v.linha}`);
      add(`Resumo por Linha × Viagens: viagens e km produtiva por linha (${rotulo})`, R.resumoLinha.map(r => {
        const doGrupo = porLinha[`${r.data}|${r.linha}`] || [];
        return {
          ok: doGrupo.length === r.viagens && igual(soma(doGrupo, 'kmProdutiva'), r.kmProdutiva),
          data: r.data, arquivo: e.arquivos.resumoLinha,
          detalhe: `linha ${r.linha}: ${doGrupo.length} viagens / ${soma(doGrupo, 'kmProdutiva')} km ≠ ${r.viagens} / ${r.kmProdutiva}`
        };
      }));
    }
    if (R.viagens && R.partidasFaixa) {
      const porFaixa = agrupar(normais, v => `${v.data}|${v.linha}|${v.hora}`);
      add(`Partidas por Faixa × Viagens: viagens por linha e hora (${rotulo})`, R.partidasFaixa.map(r => {
        const n = (porFaixa[`${r.data}|${r.linha}|${r.hora}`] || []).length;
        return { ok: n === r.viagens, data: r.data, arquivo: e.arquivos.partidasFaixa, detalhe: `linha ${r.linha} ${r.hora}h: ${n} ≠ ${r.viagens}` };
      }));
    }
    if (R.viagens && R.resumoFaixa) {
      const porHora = agrupar(normais, v => `${v.data}|${v.hora}`);
      add(`Resumo por Faixa × Viagens: viagens e veículos por hora (${rotulo})`, R.resumoFaixa.map(r => {
        const doGrupo = porHora[`${r.data}|${r.hora}`] || [];
        return {
          ok: doGrupo.length === r.viagens && distintos(doGrupo, 'prefixo') === r.veiculos,
          data: r.data, arquivo: e.arquivos.resumoFaixa,
          detalhe: `${r.hora}h: ${doGrupo.length} viagens / ${distintos(doGrupo, 'prefixo')} veículos ≠ ${r.viagens} / ${r.veiculos}`
        };
      }));
    }
    if (R.resumoFaixa && R.resumoGeral) {
      const maxPorDia = {};
      for (const r of R.resumoFaixa) maxPorDia[r.data] = Math.max(maxPorDia[r.data] ?? 0, r.veiculos);
      add(`Resumo por Faixa × Resumo Geral: máximo de veículos numa hora (${rotulo})`, R.resumoGeral.map(r => ({
        ok: maxPorDia[r.data] === r.maxVeiculosFaixa, data: r.data, arquivo: e.arquivos.resumoFaixa,
        detalhe: `máximo por faixa ${maxPorDia[r.data] ?? '-'} ≠ nrMaxVeicFx ${r.maxVeiculosFaixa}`
      })));
    }
    if (R.cumprimento && R.resumoGeral) {
      add(`Fator de Cumprimento × Resumo Geral: programadas e realizadas (${rotulo})`, R.cumprimento.map(f => {
        const r = resumoDia[f.data];
        return {
          ok: !!r && f.programadas === r.viagensProgramadas && f.realizadas === r.viagensRealizadas,
          data: f.data, arquivo: e.arquivos.cumprimento,
          detalhe: r ? `FCV ${f.programadas}/${f.realizadas} ≠ resumo ${r.viagensProgramadas}/${r.viagensRealizadas}` : 'dia ausente no Resumo Geral'
        };
      }));
    }
    const tiposNc = Object.keys(NAO_CUMPRIDAS).filter(t => R[t]);
    if (tiposNc.length && R.resumoGeral) {
      const ncPorDia = agrupar(tiposNc.flatMap(t => R[t]), r => r.data);
      add(`Não realizadas + não iniciadas + não terminadas = Dif Viagens (${rotulo})`, R.resumoGeral.map(r => ({
        ok: (ncPorDia[r.data] || []).length === r.viagensNaoCumpridas, data: r.data, arquivo: e.arquivos.resumoGeral,
        detalhe: `${(ncPorDia[r.data] || []).length} listadas ≠ Dif Viagens ${r.viagensNaoCumpridas}`
      })));
    }
  }

  // ---- Na série consolidada
  // R$ utilizado ÷ passageiro antecipado: a razão mais frequente sai dos próprios dados (não há tarifa nos arquivos)
  const comRazao = dias.filter(d => d.antecipados && d.utilizacao != null).map(d => [d, arredondar(d.utilizacao / d.antecipados)]);
  if (comRazao.length) {
    const freq = {};
    comRazao.forEach(([, razao]) => { freq[razao] = (freq[razao] || 0) + 1; });
    const [comum, vezes] = Object.entries(freq).sort((a, b) => b[1] - a[1])[0];
    add(`Créditos × Passageiros: Total Utilização ÷ Antecipados constante (R$ ${Number(comum).toFixed(2)} em ${vezes} dias)`,
      comRazao.map(([d, razao]) => ({ ok: razao === Number(comum), data: d.data, detalhe: `${d.utilizacao} ÷ ${d.antecipados} = ${razao}` })));
  }
  const comSaldo = dias.filter(d => d.saldoFinal != null);
  add('Saldo de créditos: saldo anterior − créditos transferidos = saldo final', comSaldo.slice(1).map((d, i) => {
    const diferenca = arredondar(comSaldo[i].saldoFinal - (d.transferidos || 0) - d.saldoFinal);
    return { ok: diferenca === 0, data: d.data, detalhe: `saldo caiu R$ ${diferenca.toFixed(2)} além do transferido` };
  }));
  add('Valores iguais entre emissões diferentes do mesmo dia (quinzenal × mensal)', dias.filter(d => Object.keys(d.fontes).length).map(d => ({
    ok: !d.revisoes.length, data: d.data,
    detalhe: d.revisoes.map(r => `${r.campo}: ${r.de} → ${r.para} (${r.arquivoAnterior} → ${r.arquivo})`).join('; ')
  })));
  if (dias.length) {
    const todas = [];
    for (let data = dias[0].data; data <= dias.at(-1).data; data = somarDias(data, 1)) todas.push(data);
    for (const [grupo, nome] of [['operacao', 'Operação'], ['passageiros', 'Passageiros'], ['creditos', 'Venda x Utilização']]) {
      const comDado = new Set(dias.filter(d => d.fontes[grupo]).map(d => d.data));
      add(`${nome}: todas as datas entre ${dias[0].data} e ${dias.at(-1).data} presentes`,
        todas.map(data => ({ ok: comDado.has(data), data, detalhe: 'sem registro' })));
    }
  }
  return conferencias;
}

// ==================== GRAVAÇÃO ====================

async function gravarViagens(viagensPorDia) {
  // Só reescreve os dias cuja origem mudou (a primeira carga tem ~100 mil viagens)
  const atuais = await ViagemRealizada.aggregate([{ $group: { _id: '$data', fonte: { $first: '$fonte' }, n: { $sum: 1 } } }]);
  const noBanco = Object.fromEntries(atuais.map(a => [a._id, a]));
  const mudaram = Object.keys(viagensPorDia).filter(data =>
    noBanco[data]?.fonte !== viagensPorDia[data][0]?.fonte || noBanco[data]?.n !== viagensPorDia[data].length);
  const sairam = Object.keys(noBanco).filter(data => !(data in viagensPorDia));
  if (mudaram.length || sairam.length) await ViagemRealizada.deleteMany({ data: { $in: [...mudaram, ...sairam] } });
  const novas = mudaram.flatMap(data => viagensPorDia[data]);
  for (let i = 0; i < novas.length; i += LOTE) await ViagemRealizada.insertMany(novas.slice(i, i + LOTE), { lean: true });
  return { diasAtualizados: mudaram.length, viagensGravadas: novas.length };
}

// Lê, consolida e confere sem gravar nada (usado também por npm run conferir-dados)
async function lerEConferir() {
  const { lidos, recusados } = await lerArquivos();
  const dias = consolidarDias(lidos);
  const emissoes = emissoesDeOperacao(lidos);
  const { viagens, naoCumpridas } = consolidarViagens(emissoes);
  return { lidos, recusados, dias, viagens, naoCumpridas, conferencias: conferir(lidos, emissoes, dias) };
}

async function processarDados() {
  const { lidos, recusados, dias, viagens, naoCumpridas, conferencias } = await lerEConferir();

  // Indicadores diários (agregado do sistema: linha nula)
  if (dias.length) {
    await IndicadorDiario.bulkWrite(dias.map(dia => ({
      replaceOne: { filter: { data: dia.data, linha: null }, replacement: { ...dia, linha: null }, upsert: true }
    })));
  }
  await IndicadorDiario.deleteMany({ linha: null, data: { $nin: dias.map(d => d.data) } });

  const resultadoViagens = await gravarViagens(viagens);
  // Poucas centenas: troca tudo
  await ViagemNaoCumprida.deleteMany({});
  await ViagemNaoCumprida.insertMany(Object.values(naoCumpridas).flat(), { lean: true });

  const OPERACIONAIS_DE_CONFERENCIA = ['resumoLinha', 'partidasFaixa', 'resumoFaixa'];
  const arquivos = [
    ...lidos.map(l => ({
      arquivo: l.arquivo,
      relatorios: l.relatorios.map(r => r.titulo),
      registros: l.relatorios.reduce((s, r) => s + r.registros.length, 0),
      geradoEm: l.geradoEm,
      inicio: l.inicio,
      fim: l.fim,
      // Resumo por linha e faixas horárias são deriváveis das viagens: servem só para conferir
      uso: l.relatorios.every(r => OPERACIONAIS_DE_CONFERENCIA.includes(r.tipo)) ? 'conferencia' : 'indicadores',
      identificacao: [...new Set(l.relatorios.map(r => r.identificacao))].join(', '),
      erro: l.naoReconhecidas.length ? `ignorado: ${l.naoReconhecidas.join('; ')}` : undefined
    })),
    ...recusados
  ];
  const linhas = [...new Set(Object.values(viagens).flat().map(v => v.linha).filter(Boolean))].sort();
  await ImportacaoDados.create({ arquivos, conferencias, linhas });

  return {
    dias: dias.length,
    inicio: dias[0]?.data || null,
    fim: dias.at(-1)?.data || null,
    viagens: Object.values(viagens).reduce((s, l) => s + l.length, 0),
    naoCumpridas: Object.values(naoCumpridas).reduce((s, l) => s + l.length, 0),
    ...resultadoViagens,
    arquivos,
    conferencias
  };
}

// Guarda um arquivo enviado pelo painel. Cada envio fica na sua pasta, então nomes repetidos
// (ex.: Saldos_Quinzenal.html de meses diferentes) não se sobrescrevem.
async function salvarArquivo(envio, nome, conteudo) {
  const nomeLimpo = path.basename(String(nome || ''));
  if (!/^[^\\/:*?"<>|]+\.(html?|csv)$/i.test(nomeLimpo)) throw new ErroHttp(400, 'Envie arquivos .html ou .csv');
  if (!/^\d{8}-\d{6}$/.test(String(envio))) throw new ErroHttp(400, 'Identificador do envio inválido');
  if (!Buffer.isBuffer(conteudo) || !conteudo.length) throw new ErroHttp(400, 'Arquivo vazio');

  const destino = path.join(PASTA_DADOS, 'enviados', envio);
  await fs.promises.mkdir(destino, { recursive: true });
  // Dois arquivos com o mesmo nome no mesmo envio (vindos de pastas diferentes): o segundo ganha um número
  const { name, ext } = path.parse(nomeLimpo);
  let nomeFinal = nomeLimpo;
  for (let n = 2; fs.existsSync(path.join(destino, nomeFinal)); n++) nomeFinal = `${name} (${n})${ext}`;
  await fs.promises.writeFile(path.join(destino, nomeFinal), conteudo);
  return `enviados/${envio}/${nomeFinal}`;
}

module.exports = { PASTA_DADOS, salvarArquivo, processarDados, lerEConferir, itinerario };
