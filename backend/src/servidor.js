require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');
const conectarBanco = require('./configuracao/banco');
const { iniciarTempoReal } = require('./configuracao/tempoReal');
const { iniciarSincronizadorFleetbase, pararSincronizadorFleetbase } = require('./fleetbase/sincronizadorFleetbase');
const FleetbaseService = require('./fleetbase/FleetbaseService');

// Importar rotas
const rotasOperacao = require('./rotas/rotasOperacao');
const rotasPainel = require('./rotas/rotasPainel');
const rotasAuth = require('./rotas/rotasAuth');
const rotasUsuarios = require('./rotas/rotasUsuarios');
const rotasVeiculos = require('./rotas/rotasVeiculos');
const rotasViagens = require('./rotas/rotasViagens');
const rotasLocalizacao = require('./rotas/rotasLocalizacao');
const rotasFleetbase = require('./rotas/rotasFleetbase');
const rotasIndicadores = require('./rotas/rotasIndicadores');

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
app.use('/api/fleetbase', rotasFleetbase);
app.use('/api/indicadores', rotasIndicadores);

// Rota de saúde
app.get('/api/saude', (req, res) => {
  res.json({
    status: 'ok',
    horario: new Date().toISOString(),
    servico: 'PROJETOBUS Backend',
    fleetbase: FleetbaseService.habilitado ? 'habilitado' : 'desabilitado'
  });
});

// Para os serviços em segundo plano ao encerrar o servidor
function encerrar() {
  pararSincronizadorFleetbase();
  process.exit(0);
}
process.on('SIGINT', encerrar);
process.on('SIGTERM', encerrar);

// Servidor HTTP compartilhado entre a API e o Socket.IO (tempo real do painel)
const servidorHttp = http.createServer(app);
iniciarTempoReal(servidorHttp);

// Conectar ao MongoDB, abrir a API e depois ligar o Fleetbase
conectarBanco()
  .then(() => new Promise(resolver => {
    servidorHttp.listen(PORTA, () => {
      console.log(`PROJETOBUS Backend rodando na porta ${PORTA}`);
      console.log(`Verificação de saúde: http://localhost:${PORTA}/api/saude`);
      resolver();
    });
  }))
  .then(iniciarSincronizadorFleetbase);
