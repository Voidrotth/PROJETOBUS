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
  // Consumo médio de referência (km por litro) para estimar o combustível pelos km do hodômetro,
  // enquanto não chegam os relatórios de abastecimento
  consumoKmPorLitro: {
    type: Number,
    default: null
  },
  ativo: {
    type: Boolean,
    default: true
  }
}, { timestamps: true });

module.exports = mongoose.model('Veiculo', esquemaVeiculo);
