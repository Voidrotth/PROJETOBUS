const { Server } = require('socket.io');
const { lerToken } = require('../middlewares/autenticacao');

// Tempo real do painel: só administradores recebem as posições dos ônibus
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
    if (socket.usuario.papel === 'admin') socket.join(SALA_PAINEL);
  });
}

// Eventos: viagem:iniciada, viagem:posicao, viagem:encerrada, dados:atualizados (relatórios processados)
function emitirParaPainel(evento, dados) {
  if (io) io.to(SALA_PAINEL).emit(evento, dados);
}

module.exports = { iniciarTempoReal, emitirParaPainel };
