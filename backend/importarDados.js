// Lê a pasta de dados e grava indicadores, viagens e viagens não cumpridas no banco.
// Faz o mesmo que o botão "Enviar dados" do painel, para quando os arquivos já estão na pasta.
// Uso: npm run importar-dados               (lê e grava)
//      npm run importar-dados -- --conferir (só lê e confere, não grava nem conecta ao banco)
require('dotenv').config();
const mongoose = require('mongoose');
const conectarBanco = require('./banco');
const { PASTA_DADOS, processarDados, lerEConferir } = require('./servicoIngestao');

const SO_CONFERIR = process.argv.includes('--conferir');

function mostrar({ arquivos, conferencias }) {
  for (const a of arquivos.filter(a => a.uso === 'erro')) console.log(`RECUSADO ${a.arquivo}: ${a.erro}`);
  for (const a of arquivos.filter(a => a.identificacao?.split(/, ?/).includes('ia'))) console.log(`IA       ${a.arquivo}: tipo identificado pela IA`);
  for (const c of conferencias) {
    console.log(`${c.divergencias.length ? 'ATENÇÃO' : 'ok     '} ${c.descricao}: ${c.verificados - c.divergencias.length}/${c.verificados}`);
    for (const d of c.divergencias.slice(0, 5)) console.log(`          ${d.data || ''} ${d.detalhe}`);
  }
}

async function principal() {
  if (SO_CONFERIR) {
    const r = await lerEConferir();
    const arquivos = [...r.lidos.map(l => ({ ...l, identificacao: l.relatorios.map(x => x.identificacao).join(',') })), ...r.recusados];
    console.log(`${r.lidos.length} arquivos lidos em ${PASTA_DADOS} (${r.recusados.length} recusados/repetidos)`);
    console.log(`${r.dias.length} dias: ${r.dias[0]?.data} a ${r.dias.at(-1)?.data}; ` +
      `${Object.values(r.viagens).flat().length} viagens; ${Object.values(r.naoCumpridas).flat().length} não cumpridas`);
    return mostrar({ arquivos, conferencias: r.conferencias });
  }
  await conectarBanco();
  const r = await processarDados();
  console.log(`${r.arquivos.length} arquivos lidos em ${PASTA_DADOS}`);
  console.log(`${r.dias} dias gravados: ${r.inicio} a ${r.fim}`);
  console.log(`${r.viagens} viagens (${r.viagensGravadas} regravadas em ${r.diasAtualizados} dias); ${r.naoCumpridas} não cumpridas`);
  mostrar(r);
  await mongoose.disconnect();
}

principal().catch(async erro => {
  console.error(erro.message);
  await mongoose.disconnect();
  process.exit(1);
});
