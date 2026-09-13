const mongoose = require('mongoose');

const esquemaOperacao = new mongoose.Schema({
  linha: {
    type: String,
    required: true
  },
  veiculo: {
    type: String,
    required: true
  },
  motorista: {
    type: String,
    required: true
  },
  cobrador: {
    type: String,
    default: ''
  },
  dataOperacao: {
    type: Date,
    required: true
  },
  horarioSaida: {
    type: String,
    default: ''
  },
  horarioRecolhimento: {
    type: String,
    default: ''
  },
  kmInicial: {
    type: Number,
    default: 0
  },
  kmFinal: {
    type: Number,
    default: 0
  },
  passageiros: {
    type: Number,
    default: 0
  },
  viagens: {
    type: Number,
    default: 0
  },
  ocorrencias: {
    type: String,
    default: ''
  },
  origem: {
    type: String,
    enum: ['email', 'manual'],
    required: true
  },
  importacaoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Importacao',
    default: null
  }
}, { timestamps: true });

module.exports = mongoose.model('Operacao', esquemaOperacao);
