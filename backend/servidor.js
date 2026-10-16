require('dotenv').config();

const fs = require('fs');
const http = require('http');
const path = require('path');
const express = require('express');
const cors = require('cors');
const conectarBanco = require('./banco');
const { iniciarTempoReal } = require('./tempoReal');

// Importar rotas
const rotasAuth = require('./rotasAuth');
const rotasUsuarios = require('./rotasUsuarios');
const rotasVeiculos = require('./rotasVeiculos');
const rotasIndicadores = require('./rotasIndicadores');

const app = express();
const PORTA = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rotas da API
app.use('/api/auth', rotasAuth);
app.use('/api/usuarios', rotasUsuarios);
app.use('/api/veiculos', rotasVeiculos);
app.use('/api/indicadores', rotasIndicadores);

// Rota de saúde
app.get('/api/saude', (req, res) => {
  res.json({
    status: 'ok',
    horario: new Date().toISOString(),
    servico: 'PROJETOBUS Backend'
  });
});

// Painel web (build do Flutter) no mesmo endereço da API, quando já foi compilado
// (cd frontend && flutter build web).
const PASTA_PAINEL = path.join(__dirname, '../frontend/build/web');
if (fs.existsSync(PASTA_PAINEL)) {
  app.use(express.static(PASTA_PAINEL));
  app.get(/^(?!\/api\/|\/socket\.io\/).*/, (req, res) => res.sendFile(path.join(PASTA_PAINEL, 'index.html')));
}

// Servidor HTTP compartilhado entre a API e o Socket.IO (tempo real do painel)
const servidorHttp = http.createServer(app);
iniciarTempoReal(servidorHttp);

// Conectar ao MongoDB e abrir a API
conectarBanco().then(() => {
  servidorHttp.listen(PORTA, () => {
    console.log(`PROJETOBUS Backend rodando na porta ${PORTA}`);
    console.log(`Verificação de saúde: http://localhost:${PORTA}/api/saude`);
  });
});
