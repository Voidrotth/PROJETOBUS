const mongoose = require('mongoose');

// Cada ponto de GPS enviado pelo celular do motorista durante uma viagem
const esquemaLocalizacao = new mongoose.Schema({
  viagem: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Viagem',
    required: true
  },
  veiculo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Veiculo',
    required: true
  },
  local: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true } // [longitude, latitude]
  },
  velocidade: Number,
  direcao: Number,
  precisao: Number,
  horario: {
    type: Date,
    required: true
  }
});

// Unicidade por viagem + horário: reenvios da fila offline não duplicam pontos
esquemaLocalizacao.index({ viagem: 1, horario: 1 }, { unique: true });
esquemaLocalizacao.index({ local: '2dsphere' });

module.exports = mongoose.model('Localizacao', esquemaLocalizacao, 'localizacoes');
