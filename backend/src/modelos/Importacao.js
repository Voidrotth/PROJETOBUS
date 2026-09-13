const mongoose = require('mongoose');

const esquemaImportacao = new mongoose.Schema({
  origem: {
    type: String,
    enum: ['email', 'manual'],
    required: true
  },
  remetente: {
    type: String,
    default: ''
  },
  assunto: {
    type: String,
    default: ''
  },
  conteudoOriginal: {
    type: String,
    default: ''
  },
  dadosExtraidos: {
    linha: String,
    veiculo: String,
    motorista: String,
    cobrador: String,
    dataOperacao: Date,
    horarioSaida: String,
    horarioRecolhimento: String,
    kmInicial: Number,
    kmFinal: Number,
    passageiros: Number,
    viagens: Number,
    ocorrencias: String
  },
  status: {
    type: String,
    enum: ['pendente', 'confirmado', 'rejeitado'],
    default: 'pendente'
  }
}, { timestamps: true });

module.exports = mongoose.model('Importacao', esquemaImportacao);
