const fs = require('fs');
const path = require('path');
const { Kafka, Partitioners, logLevel } = require('kafkajs');

const TOPICO_EMAILS = process.env.KAFKA_TOPICO_EMAILS || 'emails-recebidos';

// Sem KAFKA_BROKER no .env o sistema processa os e-mails direto, sem Kafka
const kafkaHabilitado = Boolean(process.env.KAFKA_BROKER);

let kafka;
let produtor;

// Lê um arquivo de certificado (caminho relativo à pasta backend)
function lerCertificado(caminho) {
  if (!caminho) return undefined;
  return fs.readFileSync(path.resolve(__dirname, '../..', caminho), 'utf-8');
}

function obterKafka() {
  if (kafka) return kafka;

  const ca = lerCertificado(process.env.KAFKA_CA);
  const configuracao = {
    clientId: 'projetobus-backend',
    brokers: process.env.KAFKA_BROKER.split(','),
    logLevel: logLevel.WARN
  };

  if (process.env.KAFKA_SASL_USUARIO) {
    // Autenticação por usuário e senha (SASL)
    configuracao.ssl = ca ? { ca: [ca] } : true;
    configuracao.sasl = {
      mechanism: 'scram-sha-256',
      username: process.env.KAFKA_SASL_USUARIO,
      password: process.env.KAFKA_SASL_SENHA
    };
  } else {
    // Autenticação por certificado (padrão da Aiven)
    configuracao.ssl = {
      ca: ca ? [ca] : undefined,
      cert: lerCertificado(process.env.KAFKA_CERT),
      key: lerCertificado(process.env.KAFKA_KEY)
    };
  }

  kafka = new Kafka(configuracao);
  return kafka;
}

// Cria o tópico (se ainda não existir) e conecta o produtor
async function conectarKafka() {
  const admin = obterKafka().admin();
  await admin.connect();
  try {
    const topicos = await admin.listTopics();
    if (!topicos.includes(TOPICO_EMAILS)) {
      await admin.createTopics({ topics: [{ topic: TOPICO_EMAILS, numPartitions: 1 }] });
      console.log(`Tópico Kafka criado: ${TOPICO_EMAILS}`);
    }
  } catch (erro) {
    console.warn(`Não foi possível criar o tópico "${TOPICO_EMAILS}" (${erro.message}). Crie-o no console da Aiven.`);
  } finally {
    await admin.disconnect();
  }

  produtor = obterKafka().producer({ createPartitioner: Partitioners.DefaultPartitioner });
  await produtor.connect();
  console.log('Kafka conectado com sucesso');
}

// Publica no tópico o ID da importação que precisa ser interpretada pela IA
async function publicarEmailRecebido(importacaoId) {
  await produtor.send({
    topic: TOPICO_EMAILS,
    messages: [{ key: String(importacaoId), value: JSON.stringify({ importacaoId: String(importacaoId) }) }]
  });
}

async function desconectarKafka() {
  if (produtor) await produtor.disconnect();
}

module.exports = {
  TOPICO_EMAILS,
  kafkaHabilitado,
  obterKafka,
  conectarKafka,
  publicarEmailRecebido,
  desconectarKafka
};
