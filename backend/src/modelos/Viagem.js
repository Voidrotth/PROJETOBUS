const mongoose = require('mongoose');

const esquemaPosicao = new mongoose.Schema({
  latitude: Number,
  longitude: Number,
  velocidade: Number,
  direcao: Number,
  precisao: Number,
  horario: Date
}, { _id: false });

// Jornada do motorista com um veículo: do "iniciar" ao "encerrar"
const esquemaViagem = new mongoose.Schema({
  motorista: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Usuario',
    required: true
  },
  veiculo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Veiculo',
    required: true
  },
  linha: {
    type: String,
    required: true
  },
  status: {
    type: String,
    enum: ['em_andamento', 'encerrada'],
    default: 'em_andamento'
  },
  inicio: {
    type: Date,
    default: Date.now
  },
  fim: {
    type: Date,
    default: null
  },
  kmInicial: {
    type: Number,
    default: 0
  },
  kmFinal: {
    type: Number,
    default: 0
  },
  // Distância calculada pelas posições de GPS (conferência do km informado)
  kmGps: {
    type: Number,
    default: 0
  },
  passageiros: {
    type: Number,
    default: 0
  },
  voltas: {
    type: Number,
    default: 0
  },
  ocorrencias: {
    type: String,
    default: ''
  },
  ultimaPosicao: {
    type: esquemaPosicao,
    default: null
  },
  totalPosicoes: {
    type: Number,
    default: 0
  },
  operacaoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Operacao',
    default: null
  }
}, { timestamps: true });

// Um motorista só pode ter uma viagem aberta, e um veículo só pode estar em uma viagem aberta
const somenteAbertas = { unique: true, partialFilterExpression: { status: 'em_andamento' } };
esquemaViagem.index({ motorista: 1 }, somenteAbertas);
esquemaViagem.index({ veiculo: 1 }, somenteAbertas);
esquemaViagem.index({ inicio: -1 });

module.exports = mongoose.model('Viagem', esquemaViagem);
