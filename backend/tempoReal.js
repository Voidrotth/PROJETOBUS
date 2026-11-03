const { Server } = require('socket.io');
const { lerToken } = require('./autenticacao');

// Tempo real do painel (administração e computador da SEMOB)
const SALA_PAINEL = 'painel';

let io;

function iniciarTempoReal(servidorHttp) {
  io = new Server(servidorHttp, { cors: { origin: '*' } });

  io.use((socket, next) => {
    try {
      socket.usuario = lerToken(socket.handshake.auth?.token);
      next();
    } catch {
      next(new Error('não autorizado'));
    }
  });

  io.on('connection', socket => {
    if (['admin', 'computador'].includes(socket.usuario.papel)) socket.join(SALA_PAINEL);
  });
}

// Evento: dados:atualizados (relatórios processados)
function emitirParaPainel(evento, dados) {
  if (io) io.to(SALA_PAINEL).emit(evento, dados);
}

module.exports = { iniciarTempoReal, emitirParaPainel };
