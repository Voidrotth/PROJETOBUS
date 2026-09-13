require('dotenv').config();

// A biblioteca kafkajs gera um TimeoutNegativeWarning inofensivo no Node 24; esconde só esse aviso
const emitirAvisoOriginal = process.emitWarning;
process.emitWarning = (aviso, ...args) => {
  const tipo = typeof args[0] === 'string' ? args[0] : args[0]?.type;
  if (tipo === 'TimeoutNegativeWarning') return;
  return emitirAvisoOriginal.call(process, aviso, ...args);
};

const express = require('express');
const cors = require('cors');
const conectarBanco = require('./configuracao/banco');
const { kafkaHabilitado, conectarKafka, desconectarKafka } = require('./configuracao/kafka');
const { iniciarConsumidorEmails, pararConsumidorEmails } = require('./consumidores/consumidorEmails');
const { iniciarLeitorCaixaEmail, pararLeitorCaixaEmail } = require('./servicos/leitorCaixaEmail');

// Importar rotas
const rotasEmail = require('./rotas/rotasEmail');
const rotasImportacao = require('./rotas/rotasImportacao');
const rotasOperacao = require('./rotas/rotasOperacao');
const rotasPainel = require('./rotas/rotasPainel');

const app = express();
const PORTA = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rotas da API
app.use('/api/email', rotasEmail);
app.use('/api/importacoes', rotasImportacao);
app.use('/api/operacoes', rotasOperacao);
app.use('/api/painel', rotasPainel);

// Rota de saúde
app.get('/api/saude', (req, res) => {
  res.json({
    status: 'ok',
    horario: new Date().toISOString(),
    servico: 'PROJETOBUS Backend',
    kafka: kafkaHabilitado ? 'habilitado' : 'desabilitado'
  });
});

// Conectar Kafka (se configurado) e iniciar o consumidor de e-mails
async function iniciarKafka() {
  if (!kafkaHabilitado) {
    console.log('Kafka desabilitado (KAFKA_BROKER não definido). E-mails serão processados direto.');
    return;
  }
  try {
    await conectarKafka();
    console.log('Aguardando o Kafka liberar o consumidor (pode levar até 30s)...');
    await iniciarConsumidorEmails();
  } catch (erro) {
    console.error('Erro ao conectar Kafka:', erro.message);
    process.exit(1);
  }
}

// Desconectar do Kafka ao encerrar o servidor
async function encerrar() {
  pararLeitorCaixaEmail();
  await pararConsumidorEmails().catch(() => {});
  await desconectarKafka().catch(() => {});
  process.exit(0);
}
process.on('SIGINT', encerrar);
process.on('SIGTERM', encerrar);

// Conectar ao MongoDB, abrir a API e depois ligar Kafka e leitura de e-mail
conectarBanco()
  .then(() => new Promise(resolver => {
    app.listen(PORTA, () => {
      console.log(`PROJETOBUS Backend rodando na porta ${PORTA}`);
      console.log(`Verificação de saúde: http://localhost:${PORTA}/api/saude`);
      resolver();
    });
  }))
  .then(iniciarKafka)
  .then(iniciarLeitorCaixaEmail);
