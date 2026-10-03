require('dotenv').config();

const fs = require('fs');
const http = require('http');
const path = require('path');
const express = require('express');
const cors = require('cors');
const conectarBanco = require('./configuracao/banco');
const { iniciarTempoReal } = require('./configuracao/tempoReal');

// Importar rotas
const rotasOperacao = require('./rotas/rotasOperacao');
const rotasPainel = require('./rotas/rotasPainel');
const rotasAuth = require('./rotas/rotasAuth');
const rotasUsuarios = require('./rotas/rotasUsuarios');
const rotasVeiculos = require('./rotas/rotasVeiculos');
const rotasViagens = require('./rotas/rotasViagens');
const rotasLocalizacao = require('./rotas/rotasLocalizacao');
const rotasIndicadores = require('./rotas/rotasIndicadores');
const rotasTransmissao = require('./rotas/rotasTransmissao');

const app = express();
const PORTA = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rotas da API
app.use('/api/operacoes', rotasOperacao);
app.use('/api/painel', rotasPainel);
app.use('/api/auth', rotasAuth);
app.use('/api/usuarios', rotasUsuarios);
app.use('/api/veiculos', rotasVeiculos);
app.use('/api/viagens', rotasViagens);
app.use('/api/localizacao', rotasLocalizacao);
app.use('/api/indicadores', rotasIndicadores);
app.use('/api/transmissao', rotasTransmissao);

// Rota de saúde
app.get('/api/saude', (req, res) => {
  res.json({
    status: 'ok',
    horario: new Date().toISOString(),
    servico: 'PROJETOBUS Backend'
  });
});

// Painel web (build do Flutter) no mesmo endereço da API, quando já foi compilado
// (cd frontend && flutter build web). Um endereço só também serve para o link https do celular.
const PASTA_PAINEL = path.join(__dirname, '../../frontend/build/web');
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
