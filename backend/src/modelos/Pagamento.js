const mongoose = require('mongoose');

// Fechamento financeiro lançado pelo motorista ao encerrar a viagem
const esquemaPagamento = new mongoose.Schema({
  viagem: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Viagem',
    required: true,
    unique: true
  },
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
    default: ''
  },
  data: {
    type: Date,
    required: true
  },
  dinheiro: {
    type: Number,
    default: 0
  },
  cartao: {
    type: Number,
    default: 0
  },
  pix: {
    type: Number,
    default: 0
  },
  gratuidades: {
    type: Number,
    default: 0
  },
  total: {
    type: Number,
    default: 0
  }
}, { timestamps: true });

module.exports = mongoose.model('Pagamento', esquemaPagamento);
