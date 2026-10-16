// npm test — leitura dos relatórios e validação da resposta da IA (sem rede e sem banco)
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { lerHtml, decodificar } = require('../src/servicos/leitorRelatorios');

// dados/ (relatórios reais) fica só na máquina; o teste usa um Resumo Geral copiado para test/dados/
const DADOS = path.join(__dirname, '../../dados');
const RESUMO = path.join(__dirname, 'dados/resumo_geral.html');
const semIA = () => { throw new Error('a IA não devia ser chamada'); };

// Resumo Geral com colunas renomeadas: a assinatura não reconhece, só a IA
function resumoRenomeado() {
  let html = decodificar(fs.readFileSync(RESUMO));
  for (const [de, para] of [['Data', 'Dia de operação'], ['kmProd', 'Km com passageiro'], ['kmImprod', 'Km vazio'], ['kmTotal', 'Km geral']]) {
    html = html.replace(`<th>${de}</th>`, `<th>${para}</th>`);
  }
  return Buffer.from(html.replaceAll('Quinzenal - Resumo Geral', 'Operação diária'), 'latin1');
}
const mapaCerto = {
  data: 'Dia de operação', diaSemana: 'diaSem', veiculos: 'nrVeiculos', maxVeiculosFaixa: 'nrMaxVeicFx',
  viagensProgramadas: 'nrViagensProgr', viagensRealizadas: 'nrViagensRealiz', viagensNaoCumpridas: 'Dif Viagens',
  kmProdutiva: 'Km com passageiro', kmImprodutiva: 'Km vazio', kmTotal: 'Km geral'
};

test('relatório conhecido é identificado pela assinatura, sem IA', async () => {
  const r = await lerHtml('resumo.html', fs.readFileSync(RESUMO), semIA);
  assert.equal(r.relatorios[0].tipo, 'resumoGeral');
  assert.equal(r.relatorios[0].registros.length, 14);
  assert.equal(r.geradoEm, '2026-09-15T08:00');
  assert.deepEqual(r.relatorios[0].registros[0], {
    data: '2026-09-01', diaSemana: 'Ter', veiculos: 51, maxVeiculosFaixa: 47, viagensProgramadas: 1280,
    viagensRealizadas: 1280, viagensNaoCumpridas: 0, kmProdutiva: 9569, kmImprodutiva: 511.9, kmTotal: 10080.9
  });
});

test('layout desconhecido usa o mapa da IA depois de validado', async () => {
  const r = await lerHtml('x.html', resumoRenomeado(), async () => ({ tipo: 'resumoGeral', mapa: mapaCerto }));
  assert.equal(r.relatorios[0].identificacao, 'ia');
  assert.equal(r.relatorios[0].registros.length, 14);
  assert.equal(r.relatorios[0].registros[0].kmImprodutiva, 511.9);
});

test('resposta da IA errada é recusada, nunca adivinhada', async () => {
  const casos = [
    [{ tipo: 'inventado', mapa: {} }, /tipo desconhecido/],
    [{ tipo: 'resumoGeral', mapa: { ...mapaCerto, kmTotal: 'Coluna que não existe' } }, /coluna que não existe/],
    [{ tipo: 'resumoGeral', mapa: { ...mapaCerto, kmTotal: undefined } }, /não encontrou colunas para kmTotal/],
    [{ tipo: 'resumoGeral', mapa: { ...mapaCerto, kmTotal: 'Km vazio' } }, /mesma coluna/],
    // Colunas trocadas: "diaSem" (texto) no lugar de um número
    [{ tipo: 'resumoGeral', mapa: { ...mapaCerto, diaSemana: 'nrVeiculos', veiculos: 'diaSem' } }, /não serve/]
  ];
  for (const [resposta, erro] of casos) {
    await assert.rejects(lerHtml('x.html', resumoRenomeado(), async () => resposta), erro);
  }
});

test('todos os arquivos de dados/ são reconhecidos pela assinatura', { skip: !fs.existsSync(DADOS) && 'pasta dados/ ausente' }, async () => {
  const contagem = {};
  // dados/enviados/ guarda cópias dos uploads do painel (a importação descarta as repetidas)
  const relatorios = fs.readdirSync(DADOS, { recursive: true }).filter(a => /\.html$/i.test(a) && !/^enviados[\\/]/.test(a));
  for (const arquivo of relatorios) {
    const r = await lerHtml(arquivo, fs.readFileSync(path.join(DADOS, arquivo)), semIA);
    for (const rel of r.relatorios) contagem[rel.tipo] = (contagem[rel.tipo] || 0) + rel.registros.length;
  }
  assert.deepEqual(contagem, {
    resumoGeral: 90, cumprimento: 90, resumoLinha: 824, partidasFaixa: 16537, resumoFaixa: 1890, viagens: 107927,
    naoRealizadas: 125, naoIniciadas: 15, naoTerminadas: 21, passageiros: 78, saldo: 65, creditos: 89
  });
});
