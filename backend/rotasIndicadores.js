const express = require('express');
const ExcelJS = require('exceljs');
const roteador = express.Router();
const IndicadorDiario = require('./IndicadorDiario');
const ImportacaoDados = require('./ImportacaoDados');
const Feriado = require('./Feriado');
const ViagemRealizada = require('./ViagemRealizada');
const ViagemNaoCumprida = require('./ViagemNaoCumprida');
const { salvarArquivo, processarDados } = require('./servicoIngestao');
const { autenticar, exigirPapel } = require('./autenticacao');
const { rota, ErroHttp } = require('./tratarErro');
const { emitirParaPainel } = require('./tempoReal');

roteador.use(autenticar);
// A TV só lê os indicadores (GET /); o resto é da administração
roteador.use((req, res, next) => (req.method === 'GET' && req.path === '/' ? next() : exigirPapel('admin')(req, res, next)));

const TIPOS_DIA = {
  util: 'Dia útil',
  nao_util: 'Dia não útil (sábado e domingo)',
  feriado: 'Feriado'
};
const DIAS_SEMANA = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
const FORMATO_DATA = /^\d{4}-\d{2}-\d{2}$/;

// Alerta do crédito circulante: semanas (seg–dom) seguidas, contando da mais recente do período para
// trás, em que se vendeu mais crédito do que se validou na catraca. A especificação pede o alerta
// mas não fixa os limites; estes são os adotados.
const SEMANAS_ALERTA_AMARELO = 2;
const SEMANAS_ALERTA_VERMELHO = 4;

// [campo, título, soma no total?]
const COLUNAS = [
  ['data', 'Data', false],
  ['diaSemana', 'Dia', false],
  ['tipoDia', 'Tipo de dia', false],
  ['veiculos', 'Veículos', false],
  ['viagensProgramadas', 'Viagens programadas', true],
  ['viagensRealizadas', 'Viagens realizadas', true],
  ['kmProdutiva', 'Km produtiva', true],
  ['kmImprodutiva', 'Km improdutiva', true],
  ['kmTotal', 'Km total', true],
  ['passageiros', 'Demanda total de passageiros', true],
  ['pagantes', 'Passageiros pagantes', true],
  ['naoPagantes', 'Passageiros gratuitos', true],
  ['catraca', 'Pagantes na catraca', true],
  ['antecipados', 'Pagantes com crédito antecipado', true],
  ['vendas', 'Receita antecipada - créditos vendidos (R$)', true],
  ['receitaCatracaDinheiro', 'Receita de catraca em dinheiro (R$)', true],
  ['receitaCatracaCartao', 'Receita de catraca em cartão (R$)', true],
  ['utilizacao', 'Créditos validados na catraca (R$)', true],
  ['circulante', 'Crédito circulante do dia (R$)', true],
  ['circulanteAcumulado', 'Crédito circulante acumulado no período (R$)', false],
  ['transferidos', 'Créditos transferidos para cartões (R$)', true],
  ['saldoFinal', 'Saldo final de créditos (R$)', false]
];
const COLUNAS_KM = COLUNAS.slice(0, 9);
const SOMAVEIS = COLUNAS.filter(c => c[2]).map(c => c[0]);
// Campo que indica que o dia tem dados de cada grupo
const GRUPOS = {
  operacao: 'kmTotal',
  passageiros: 'passageiros',
  creditos: 'vendas',
  saldo: 'saldoFinal',
  receitaCatraca: 'receitaCatraca'
};

const arredondar = valor => Math.round(valor * 100) / 100;
const somar = (dias, campo) => arredondar(dias.reduce((soma, d) => soma + (d[campo] || 0), 0));
const segundaDaSemana = dia =>
  new Date(Date.parse(dia.data) - DIAS_SEMANA.indexOf(dia.diaSemana) * 86400000).toISOString().slice(0, 10);

function estatisticas(valores) {
  if (!valores.length) return null;
  const ordenados = [...valores].sort((a, b) => a - b);
  const meio = ordenados.length >> 1;
  const media = valores.reduce((s, v) => s + v, 0) / valores.length;
  return {
    n: valores.length,
    media: Math.round(media),
    mediana: ordenados.length % 2 ? ordenados[meio] : (ordenados[meio - 1] + ordenados[meio]) / 2,
    // desvio padrão populacional
    desvio: Math.round(Math.sqrt(valores.reduce((s, v) => s + (v - media) ** 2, 0) / valores.length)),
    minimo: ordenados[0],
    maximo: ordenados.at(-1)
  };
}

function agruparPorSemana(dias) {
  const semanas = {};
  for (const dia of dias) (semanas[segundaDaSemana(dia)] ??= []).push(dia);
  return Object.entries(semanas);
}

// Dia de maior demanda de cada semana (Seg–Dom) com os 7 dias de passageiros
function picosSemanais(dias) {
  return agruparPorSemana(dias.filter(d => d.passageiros != null))
    .filter(([, diasDaSemana]) => diasDaSemana.length === 7)
    .map(([semana, diasDaSemana]) => {
      const pico = diasDaSemana.reduce((maior, d) => (d.passageiros > maior.passageiros ? d : maior));
      return { semana, data: pico.data, diaSemana: pico.diaSemana, tipoDia: pico.tipoDia, passageiros: pico.passageiros };
    });
}

// Painel de alerta do crédito circulante (ver SEMANAS_ALERTA_* no topo)
function alertaCirculante(dias) {
  if (!dias.length) return null;
  const inicio = dias[0].data;
  const fim = dias.at(-1).data;
  // Só semanas inteiras dentro do período: uma semana cortada ao meio não é comparável
  const semanas = agruparPorSemana(dias)
    .filter(([segunda]) => segunda >= inicio && new Date(Date.parse(segunda) + 6 * 86400000).toISOString().slice(0, 10) <= fim)
    .map(([semana, daSemana]) => ({
      semana,
      vendas: somar(daSemana, 'vendas'),
      utilizacao: somar(daSemana, 'utilizacao'),
      circulante: somar(daSemana, 'circulante')
    }));
  let semanasSeguidas = 0;
  for (let i = semanas.length - 1; i >= 0 && semanas[i].circulante > 0; i--) semanasSeguidas++;
  const nivel = semanasSeguidas >= SEMANAS_ALERTA_VERMELHO ? 'vermelho' : semanasSeguidas >= SEMANAS_ALERTA_AMARELO ? 'amarelo' : 'normal';
  return {
    nivel,
    semanasSeguidas,
    regra: `Amarelo: ${SEMANAS_ALERTA_AMARELO} ou mais semanas completas seguidas com vendas de crédito acima das validações. ` +
      `Vermelho: ${SEMANAS_ALERTA_VERMELHO} ou mais.`,
    semanas
  };
}

function resumirMeses(dias) {
  const meses = {};
  for (const dia of dias) (meses[dia.data.slice(0, 7)] ??= []).push(dia);
  return Object.entries(meses).map(([mes, doMes]) => ({
    mes,
    inicio: doMes[0].data,
    fim: doMes.at(-1).data,
    dias: doMes.length,
    ...Object.fromEntries(Object.keys(TIPOS_DIA).map(tipo => [tipo, doMes.filter(d => d.tipoDia === tipo).length])),
    ...Object.fromEntries(Object.entries(GRUPOS).map(([grupo, campo]) => [`dias_${grupo}`, doMes.filter(d => d[campo] != null).length])),
    ...Object.fromEntries(SOMAVEIS.map(campo => [campo, somar(doMes, campo)]))
  }));
}

// Filtros: ?inicio=AAAA-MM-DD&fim=AAAA-MM-DD&tipos=util,nao_util,feriado
async function consultar({ inicio, fim, tipos }) {
  if ((inicio && !FORMATO_DATA.test(inicio)) || (fim && !FORMATO_DATA.test(fim))) {
    throw new ErroHttp(400, 'Datas devem estar no formato AAAA-MM-DD');
  }
  const tiposEscolhidos = tipos ? String(tipos).split(',') : Object.keys(TIPOS_DIA);
  if (tiposEscolhidos.some(tipo => !TIPOS_DIA[tipo])) throw new ErroHttp(400, 'Tipo de dia inválido');

  // ponytail: carrega a série inteira (1 registro por dia, ~365/ano); filtrar no banco se passar de alguns anos
  const [todos, feriados] = await Promise.all([
    IndicadorDiario.find({ linha: null }).sort({ data: 1 }).select('-_id -__v -createdAt -updatedAt -linha').lean(),
    Feriado.find().sort({ data: 1 }).select('-_id data nome').lean()
  ]);

  // Tipo de dia: feriado cadastrado pelo gestor > sábado/domingo > dia útil
  const nomeDoFeriado = Object.fromEntries(feriados.map(f => [f.data, f.nome]));
  for (const dia of todos) {
    dia.tipoDia = dia.data in nomeDoFeriado ? 'feriado' : ['Sab', 'Dom'].includes(dia.diaSemana) ? 'nao_util' : 'util';
    if (dia.tipoDia === 'feriado') dia.feriado = nomeDoFeriado[dia.data];
    dia.pagantes = dia.passageiros == null ? null : (dia.catraca || 0) + (dia.antecipados || 0);
    dia.receitaCatraca = dia.receitaCatracaDinheiro == null && dia.receitaCatracaCartao == null
      ? null
      : arredondar((dia.receitaCatracaDinheiro || 0) + (dia.receitaCatracaCartao || 0));
  }

  const cobertura = Object.fromEntries(Object.entries(GRUPOS).map(([grupo, campo]) => {
    const comDado = todos.filter(d => d[campo] != null);
    return [grupo, { inicio: comDado[0]?.data || null, fim: comDado.at(-1)?.data || null, dias: comDado.length }];
  }));

  // O acumulado parte de zero no início do período escolhido e considera todos os tipos de dia
  const noPeriodo = todos.filter(d => (!inicio || d.data >= inicio) && (!fim || d.data <= fim));
  let acumulado = null;
  for (const dia of noPeriodo) {
    if (dia.circulante != null) acumulado = arredondar((acumulado || 0) + dia.circulante);
    dia.circulanteAcumulado = acumulado;
  }
  const dias = noPeriodo.filter(d => tiposEscolhidos.includes(d.tipoDia));

  const demandaDe = filtro => estatisticas(dias.filter(d => d.passageiros != null && filtro(d)).map(d => d.passageiros));
  return {
    filtros: { inicio: inicio || null, fim: fim || null, tipos: tiposEscolhidos },
    cobertura,
    feriados,
    // Seg–sex com programação de viagens reduzida que ainda não foram cadastrados como feriado
    sugestoesFeriado: todos.filter(d => d.programacaoReduzida && d.tipoDia !== 'feriado')
      .map(d => ({ data: d.data, diaSemana: d.diaSemana, viagensProgramadas: d.viagensProgramadas })),
    dias,
    meses: resumirMeses(dias),
    demanda: {
      geral: demandaDe(() => true),
      porTipo: Object.keys(TIPOS_DIA).map(tipo => ({ tipo, ...demandaDe(d => d.tipoDia === tipo) })).filter(e => e.n),
      porDiaSemana: DIAS_SEMANA.map(diaSemana => ({ diaSemana, ...demandaDe(d => d.diaSemana === diaSemana) })).filter(e => e.n),
      // O pico considera só os dias dos tipos escolhidos, mas exige a semana inteira com passageiros
      picosSemanais: picosSemanais(noPeriodo).filter(pico => tiposEscolhidos.includes(pico.tipoDia))
    },
    alertaCirculante: alertaCirculante(noPeriodo.filter(d => d.circulante != null))
  };
}

const ultimaImportacao = () => ImportacaoDados.findOne().sort({ createdAt: -1 }).select('-_id -__v').lean();

// GET /api/indicadores
roteador.get('/', rota(async (req, res) => {
  const [resultado, importacao] = await Promise.all([consultar(req.query), ultimaImportacao()]);
  res.json({ ...resultado, importacao });
}));

// ==================== OPERAÇÃO (VIAGENS UMA A UMA) ====================

const LINHA = /^\d{2}$/;
const TURNOS = ['manha', 'tarde', 'noite'];

// Dias do período e dos tipos escolhidos (mesmos filtros da Verificação) + filtro opcional de linha
async function filtroOperacao(query) {
  if (query.linha && !LINHA.test(query.linha)) throw new ErroHttp(400, 'Linha deve ter 2 dígitos (ex.: 01)');
  const { dias, filtros, cobertura } = await consultar(query);
  const comOperacao = dias.filter(d => d.kmTotal != null);
  return {
    dias: comOperacao,
    filtros,
    cobertura: cobertura.operacao,
    match: { data: { $in: comOperacao.map(d => d.data) }, ...(query.linha && { linha: query.linha }) }
  };
}

// GET /api/indicadores/operacao?inicio&fim&tipos&linha
// Tudo que sai das viagens: por linha, por hora, por veículo, turnos e viagens não cumpridas
roteador.get('/operacao', rota(async (req, res) => {
  const { dias, filtros, cobertura, match } = await filtroOperacao(req.query);
  const linha = req.query.linha || null;
  const normais = { ...match, atividade: 'normal' };

  const [linhas, porLinha, porHora, porLinhaHora, frota, naoCumpridas] = await Promise.all([
    ViagemRealizada.distinct('linha', { atividade: 'normal' }),
    ViagemRealizada.aggregate([
      { $match: normais },
      { $group: { _id: '$linha', viagens: { $sum: 1 }, kmProdutiva: { $sum: '$kmProdutiva' }, veiculos: { $addToSet: '$prefixo' }, dias: { $addToSet: '$data' } } },
      { $project: { _id: 0, linha: '$_id', viagens: 1, kmProdutiva: { $round: ['$kmProdutiva', 1] }, veiculos: { $size: '$veiculos' }, dias: { $size: '$dias' } } },
      { $sort: { linha: 1 } }
    ]),
    // Por hora: viagens por dia e veículos simultâneos (média e máximo entre os dias)
    ViagemRealizada.aggregate([
      { $match: normais },
      { $group: { _id: { data: '$data', hora: '$hora' }, viagens: { $sum: 1 }, veiculos: { $addToSet: '$prefixo' } } },
      { $group: { _id: '$_id.hora', viagens: { $sum: '$viagens' }, dias: { $sum: 1 }, veiculosMedia: { $avg: { $size: '$veiculos' } }, veiculosMax: { $max: { $size: '$veiculos' } } } },
      { $project: { _id: 0, hora: '$_id', viagens: 1, dias: 1, veiculosMedia: { $round: ['$veiculosMedia', 1] }, veiculosMax: 1 } },
      { $sort: { hora: 1 } }
    ]),
    ViagemRealizada.aggregate([
      { $match: normais },
      { $group: { _id: { linha: '$linha', hora: '$hora' }, viagens: { $sum: 1 } } },
      { $project: { _id: 0, linha: '$_id.linha', hora: '$_id.hora', viagens: 1 } }
    ]),
    // Por veículo: inclui a km improdutiva (que não tem linha); com linha escolhida, só as viagens dela
    ViagemRealizada.aggregate([
      { $match: linha ? normais : match },
      { $group: {
        _id: '$prefixo',
        dias: { $addToSet: '$data' },
        viagens: { $sum: { $cond: [{ $eq: ['$atividade', 'normal'] }, 1, 0] } },
        kmProdutiva: { $sum: '$kmProdutiva' },
        kmImprodutiva: { $sum: '$kmImprodutiva' },
        linhas: { $addToSet: '$linha' }
      } },
      { $project: {
        _id: 0, prefixo: '$_id', dias: { $size: '$dias' }, viagens: 1,
        kmProdutiva: { $round: ['$kmProdutiva', 1] }, kmImprodutiva: { $round: ['$kmImprodutiva', 1] },
        linhas: { $filter: { input: '$linhas', cond: { $ne: ['$$this', null] } } }
      } },
      { $sort: { prefixo: 1 } }
    ]),
    ViagemNaoCumprida.find(match).sort({ inicioProgramado: 1 }).select('-_id').lean()
  ]);
  for (const v of frota) v.linhas.sort();

  const contar = (lista, chave) => Object.entries(lista.reduce((m, x) => ((m[x[chave]] = (m[x[chave]] || 0) + 1), m), {}))
    .map(([valor, quantidade]) => ({ [chave]: valor, quantidade })).sort((a, b) => b.quantidade - a.quantidade);
  const realizadas = porLinha.reduce((s, l) => s + l.viagens, 0);
  // Programadas, km improdutiva e turnos só existem para o sistema inteiro (não por linha)
  const programadas = linha ? null : somar(dias, 'viagensProgramadas');
  const kmProdutiva = arredondar(porLinha.reduce((s, l) => s + l.kmProdutiva, 0));

  res.json({
    filtros: { ...filtros, linha },
    cobertura,
    linhas: linhas.sort(),
    resumo: {
      dias: dias.length,
      viagensProgramadas: programadas,
      viagensRealizadas: realizadas,
      cumprimento: programadas ? Math.round((realizadas / programadas) * 10000) / 100 : null,
      viagensNaoCumpridas: naoCumpridas.length,
      kmProdutiva,
      kmImprodutiva: linha ? null : somar(dias, 'kmImprodutiva'),
      kmTotal: linha ? null : somar(dias, 'kmTotal'),
      frotaMedia: linha ? null : Math.round((dias.reduce((s, d) => s + (d.veiculos || 0), 0) / (dias.length || 1)) * 10) / 10,
      frotaMaxima: linha ? null : Math.max(0, ...dias.map(d => d.veiculos || 0)),
      veiculosDistintos: frota.length
    },
    turnos: linha ? null : TURNOS.map(turno => ({
      turno,
      programadas: somar(dias, `${turno}Programadas`),
      realizadas: somar(dias, `${turno}Realizadas`)
    })),
    porLinha,
    porHora,
    porLinhaHora,
    frota,
    naoCumpridas: {
      lista: naoCumpridas,
      porTipo: contar(naoCumpridas, 'tipo'),
      porLinha: contar(naoCumpridas, 'linha'),
      porMotorista: contar(naoCumpridas, 'motorista')
    }
  });
}));

// GET /api/indicadores/viagens?inicio&fim&tipos&linha&prefixo&sentido&hora&pagina
// Pesquisa de viagens (200 por página)
roteador.get('/viagens', rota(async (req, res) => {
  const { match } = await filtroOperacao(req.query);
  const { prefixo, sentido, hora } = req.query;
  if (sentido && !['ida', 'volta'].includes(sentido)) throw new ErroHttp(400, 'Sentido deve ser ida ou volta');
  if (hora && !/^\d{1,2}$/.test(hora)) throw new ErroHttp(400, 'Hora inválida');
  const filtro = {
    ...match,
    ...(prefixo && { prefixo: String(prefixo) }),
    ...(sentido && { sentido }),
    ...(hora && { hora: Number(hora) })
  };
  const pagina = Math.max(1, Number(req.query.pagina) || 1);
  const POR_PAGINA = 200;
  const [total, viagens] = await Promise.all([
    ViagemRealizada.countDocuments(filtro),
    ViagemRealizada.find(filtro).sort({ data: 1, inicio: 1, prefixo: 1 }).skip((pagina - 1) * POR_PAGINA).limit(POR_PAGINA).select('-_id').lean()
  ]);
  res.json({ total, pagina, porPagina: POR_PAGINA, viagens });
}));

// ==================== ENVIO DE DADOS ====================

// POST /api/indicadores/arquivos?envio=AAAAMMDD-HHMMSS&nome=arquivo.html   (corpo = o arquivo)
// Aceita o HTML do Smart Report e planilhas CSV; só guarda o arquivo, quem lê é o /processar
roteador.post('/arquivos', express.raw({ type: () => true, limit: '60mb' }), rota(async (req, res) => {
  const arquivo = await salvarArquivo(req.query.envio, req.query.nome, req.body);
  res.status(201).json({ arquivo, bytes: req.body.length });
}));

// POST /api/indicadores/processar
// Pede ao serviço de ingestão (Dart) que releia a pasta de dados e grava o resultado
roteador.post('/processar', rota(async (req, res) => {
  const resultado = await processarDados();
  // Painéis abertos se atualizam sozinhos
  emitirParaPainel('dados:atualizados', { inicio: resultado.inicio, fim: resultado.fim, dias: resultado.dias });
  res.json(resultado);
}));

// GET /api/indicadores/importacao  (arquivos lidos e conferências da última leitura)
roteador.get('/importacao', rota(async (req, res) => {
  res.json(await ultimaImportacao());
}));

// ==================== FERIADOS ====================

// PUT /api/indicadores/feriados/:data  { nome }
roteador.put('/feriados/:data', rota(async (req, res) => {
  if (!FORMATO_DATA.test(req.params.data)) throw new ErroHttp(400, 'Data deve estar no formato AAAA-MM-DD');
  const feriado = await Feriado.findOneAndUpdate(
    { data: req.params.data },
    { nome: String(req.body.nome || '') },
    { new: true, upsert: true, runValidators: true }
  );
  res.json(feriado);
}));

// DELETE /api/indicadores/feriados/:data
roteador.delete('/feriados/:data', rota(async (req, res) => {
  await Feriado.deleteOne({ data: req.params.data });
  res.status(204).end();
}));

// ==================== EXPORTAÇÃO ====================

const linhaTotal = (dias, colunas) => colunas.map(([campo, , soma], i) => (i === 0 ? 'Total' : soma ? somar(dias, campo) : null));
const celula = (dia, campo) => (campo === 'tipoDia' ? TIPOS_DIA[dia.tipoDia] : dia[campo] ?? null);

// GET /api/indicadores/exportar?formato=csv|xlsx&escopo=tudo|quilometragem (+ os mesmos filtros da consulta)
roteador.get('/exportar', rota(async (req, res) => {
  const { formato = 'csv', escopo = 'tudo' } = req.query;
  if (!['csv', 'xlsx'].includes(formato)) throw new ErroHttp(400, 'Formato deve ser csv ou xlsx');
  const { dias, meses, filtros } = await consultar(req.query);
  if (!dias.length) throw new ErroHttp(404, 'Nenhum dia nos filtros escolhidos');

  const colunas = escopo === 'quilometragem' ? COLUNAS_KM : COLUNAS;
  const linhas = [...dias.map(dia => colunas.map(([campo]) => celula(dia, campo))), linhaTotal(dias, colunas)];
  const nome = `${escopo === 'quilometragem' ? 'quilometragem' : 'indicadores'}_${dias[0].data}_${dias.at(-1).data}.${formato}`;
  res.setHeader('Content-Disposition', `attachment; filename="${nome}"`);

  if (formato === 'csv') {
    // Separador ; e vírgula decimal: abre direto no Excel em português
    const texto = valor => (typeof valor === 'number' ? String(valor).replace('.', ',') : valor ?? '');
    const csv = [colunas.map(c => c[1]), ...linhas].map(linha => linha.map(texto).join(';')).join('\r\n');
    return res.type('text/csv; charset=utf-8').send('﻿' + csv);
  }

  const planilha = new ExcelJS.Workbook();
  const adicionar = (titulo, cabecalho, conteudo) => {
    const aba = planilha.addWorksheet(titulo);
    aba.addRow(cabecalho).font = { bold: true };
    aba.addRows(conteudo);
    aba.columns.forEach(coluna => { coluna.width = 18; });
  };
  adicionar(escopo === 'quilometragem' ? 'Quilometragem' : 'Diário', colunas.map(c => c[1]), linhas);
  if (escopo !== 'quilometragem') {
    const camposMes = Object.keys(meses[0]);
    adicionar('Resumo mensal', camposMes, meses.map(mes => camposMes.map(campo => mes[campo])));
    const importacao = await ultimaImportacao();
    adicionar('Conferência', ['Conferência', 'Verificados', 'Divergências', 'Data', 'Arquivo', 'Detalhe'],
      (importacao?.conferencias || []).flatMap(c => [
        [c.descricao, c.verificados, c.divergencias.length],
        ...c.divergencias.map(d => [null, null, null, d.data, d.arquivo, d.detalhe])
      ]));
  }
  adicionar('Filtros', ['Filtro', 'Valor'], [
    ['Início', filtros.inicio || dias[0].data],
    ['Fim', filtros.fim || dias.at(-1).data],
    ['Tipos de dia', filtros.tipos.map(tipo => TIPOS_DIA[tipo]).join(', ')]
  ]);
  res.type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.send(Buffer.from(await planilha.xlsx.writeBuffer()));
}));

// GET /api/indicadores/relatorio-quilometragem (+ os mesmos filtros da consulta)
// Página simples para imprimir ou salvar em PDF pelo navegador
roteador.get('/relatorio-quilometragem', rota(async (req, res) => {
  const { dias, meses, filtros } = await consultar(req.query);
  const comKm = dias.filter(d => d.kmTotal != null);
  if (!comKm.length) throw new ErroHttp(404, 'Nenhum dia com quilometragem nos filtros escolhidos');

  const km = valor => valor.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
  const inteiro = valor => valor.toLocaleString('pt-BR');
  const dataBr = data => data.split('-').reverse().join('/');
  const numeros = d => `<td>${inteiro(d.viagensProgramadas)}</td><td>${inteiro(d.viagensRealizadas)}</td>` +
    `<td>${km(d.kmProdutiva)}</td><td>${km(d.kmImprodutiva)}</td><td>${km(d.kmTotal)}</td>`;
  const total = Object.fromEntries(['viagensProgramadas', 'viagensRealizadas', 'kmProdutiva', 'kmImprodutiva', 'kmTotal']
    .map(campo => [campo, somar(comKm, campo)]));

  res.type('html').send(`<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Relatório de Quilometragem ${dataBr(comKm[0].data)} a ${dataBr(comKm.at(-1).data)}</title>
<style>
  body { font-family: system-ui, "Segoe UI", sans-serif; color: #0b0b0b; margin: 24px; font-size: 12px; }
  h1 { font-size: 18px; margin: 0 0 4px; }
  h2 { font-size: 14px; margin: 20px 0 6px; }
  p { margin: 2px 0; color: #52514e; }
  table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
  th, td { border-bottom: 1px solid #e1e0d9; padding: 3px 8px; text-align: right; }
  th:nth-child(-n+3), td:nth-child(-n+3) { text-align: left; }
  thead { display: table-header-group; }
  tr.total td { font-weight: bold; border-top: 1px solid #0b0b0b; }
  button { margin: 12px 0; padding: 6px 14px; }
  @media print { button { display: none; } body { margin: 0; } }
</style>
</head>
<body>
<h1>Relatório de Quilometragem</h1>
<p>Período: ${dataBr(comKm[0].data)} a ${dataBr(comKm.at(-1).data)} (${comKm.length} dias)</p>
<p>Tipos de dia: ${filtros.tipos.map(tipo => TIPOS_DIA[tipo]).join(', ')}</p>
<p>Fonte: relatórios "Resumo Geral" enviados ao sistema. Km total = km produtiva + km improdutiva.</p>
<button onclick="window.print()">Imprimir / salvar em PDF</button>

<h2>Consolidado por mês</h2>
<table>
<thead><tr><th>Mês</th><th>Dias</th><th></th><th>Viagens programadas</th><th>Viagens realizadas</th><th>Km produtiva</th><th>Km improdutiva</th><th>Km total</th></tr></thead>
<tbody>
${meses.filter(m => m.dias_operacao).map(m => `<tr><td>${m.mes.slice(5)}/${m.mes.slice(0, 4)}</td><td>${m.dias_operacao}</td><td></td>${numeros(m)}</tr>`).join('\n')}
<tr class="total"><td>Total</td><td>${comKm.length}</td><td></td>${numeros(total)}</tr>
</tbody>
</table>

<h2>Dia a dia</h2>
<table>
<thead><tr><th>Data</th><th>Dia</th><th>Tipo de dia</th><th>Viagens programadas</th><th>Viagens realizadas</th><th>Km produtiva</th><th>Km improdutiva</th><th>Km total</th></tr></thead>
<tbody>
${comKm.map(d => `<tr><td>${dataBr(d.data)}</td><td>${d.diaSemana}</td><td>${TIPOS_DIA[d.tipoDia]}</td>${numeros(d)}</tr>`).join('\n')}
<tr class="total"><td>Total</td><td></td><td></td>${numeros(total)}</tr>
</tbody>
</table>
</body>
</html>`);
}));

module.exports = roteador;
