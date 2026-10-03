const mongoose = require('mongoose');

const esquemaVeiculo = new mongoose.Schema({
  placa: {
    type: String,
    required: true,
    unique: true,
    uppercase: true,
    trim: true
  },
  prefixo: {
    type: String,
    default: ''
  },
  marca: {
    type: String,
    default: ''
  },
  modelo: {
    type: String,
    default: ''
  },
  ano: {
    type: Number,
    default: null
  },
  capacidade: {
    type: Number,
    default: 0
  },
  hodometro: {
    type: Number,
    default: 0
  },
  ativo: {
    type: Boolean,
    default: true
  },
  // Relação com o veículo no Fleetbase
  fleetbaseId: {
    type: String,
    default: null
  },
  fleetbasePendente: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

module.exports = mongoose.model('Veiculo', esquemaVeiculo);
