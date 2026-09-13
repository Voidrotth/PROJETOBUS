const { obterKafka, TOPICO_EMAILS } = require('../configuracao/kafka');
const { extrairDadosDaImportacao } = require('../servicos/servicoEmail');

let consumidor;

// Lê as mensagens do tópico de e-mails e envia cada importação para a IA
async function iniciarConsumidorEmails() {
  consumidor = obterKafka().consumer({ groupId: 'projetobus-processador-emails' });
  await consumidor.connect();
  await consumidor.subscribe({ topic: TOPICO_EMAILS, fromBeginning: false });

  await consumidor.run({
    eachMessage: async ({ message }) => {
      try {
        const { importacaoId } = JSON.parse(message.value.toString());
        console.log(`Mensagem Kafka recebida: ${importacaoId}`);
        await extrairDadosDaImportacao(importacaoId);
      } catch (erro) {
        // Não relança o erro para a mensagem não ficar travada sendo reprocessada
        console.error('Erro ao processar mensagem Kafka:', erro.message);
      }
    }
  });

  console.log(`Consumidor Kafka ouvindo o tópico: ${TOPICO_EMAILS}`);
}

async function pararConsumidorEmails() {
  if (consumidor) await consumidor.disconnect();
}

module.exports = { iniciarConsumidorEmails, pararConsumidorEmails };
