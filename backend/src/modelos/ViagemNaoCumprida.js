const mongoose = require('mongoose');

// Viagem programada que não foi realizada, iniciada ou terminada (relatórios Viag_NRealiz/Ninic/NTerm)
const esquemaViagemNaoCumprida = new mongoose.Schema({
  tipo: { type: String, enum: ['nao_realizada', 'nao_iniciada', 'nao_terminada'], required: true },
  data: { type: String, required: true }, // AAAA-MM-DD
  linha: { type: String, required: true },
  atendimento: { type: String, required: true }, // como veio no relatório
  itinerario: { type: String, required: true }, // atendimento sem acento e sem abreviação, para agrupar
  prefixo: { type: String, default: null }, // vazio nas não realizadas
  motorista: { type: String, required: true },
  sentido: { type: String, enum: ['ida', 'volta'], required: true },
  tabela: { type: String, required: true },
  // Códigos que o relatório não explica (RG, AD, AT): guardados como vieram
  statusSaida: { type: String, default: null },
  statusChegada: { type: String, default: null },
  inicioProgramado: { type: Date, required: true },
  fimProgramado: { type: Date, required: true },
  inicioRealizado: { type: Date, default: null },
  fimRealizado: { type: Date, default: null },
  fonte: { type: String, required: true }
}, { versionKey: false });

esquemaViagemNaoCumprida.index({ data: 1, linha: 1, tabela: 1, inicioProgramado: 1 }, { unique: true });

module.exports = mongoose.model('ViagemNaoCumprida', esquemaViagemNaoCumprida, 'viagensnaocumpridas');
