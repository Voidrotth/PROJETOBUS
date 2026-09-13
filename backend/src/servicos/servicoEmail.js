const Importacao = require('../modelos/Importacao');
const { interpretarTextoEmail } = require('./servicoIA');
const { kafkaHabilitado, publicarEmailRecebido } = require('../configuracao/kafka');

/**
 * Envia o texto original de uma importação para a IA e salva os dados extraídos.
 * Usado tanto pelo consumidor Kafka quanto pelo processamento direto (sem Kafka).
 */
async function extrairDadosDaImportacao(importacaoId) {
  const importacao = await Importacao.findById(importacaoId);
  if (!importacao) {
    console.warn(`Importação não encontrada: ${importacaoId}`);
    return null;
  }
  if (importacao.status !== 'pendente') {
    return importacao;
  }

  try {
    importacao.dadosExtraidos = await interpretarTextoEmail(importacao.conteudoOriginal);
    await importacao.save();
    console.log(`Dados extraídos pela IA: ${importacao._id}`);
  } catch (erroIA) {
    // Mantém a importação pendente com dados vazios para revisão manual
    console.error(`Erro na IA (${importacao._id}):`, erroIA.message);
  }

  return importacao;
}

/**
 * Registra um e-mail recebido (webhook ou caixa de entrada IMAP):
 * cria a importação pendente e envia para a IA pelo Kafka ou direto.
 */
async function registrarEmailRecebido({ remetente, assunto, texto }) {
  let importacao = new Importacao({
    origem: 'email',
    remetente: remetente || 'desconhecido',
    assunto: assunto || 'Sem assunto',
    conteudoOriginal: texto,
    dadosExtraidos: {},
    status: 'pendente'
  });

  await importacao.save();

  let viaKafka = false;
  if (kafkaHabilitado) {
    try {
      await publicarEmailRecebido(importacao._id);
      viaKafka = true;
    } catch (erroKafka) {
      console.error('Erro ao publicar no Kafka, processando direto:', erroKafka.message);
    }
  }
  if (!viaKafka) {
    importacao = await extrairDadosDaImportacao(importacao._id);
  }

  console.log(`E-mail recebido: ${importacao._id}${viaKafka ? ' (enviado ao Kafka)' : ''}`);
  return { importacao, viaKafka };
}

module.exports = { extrairDadosDaImportacao, registrarEmailRecebido };
