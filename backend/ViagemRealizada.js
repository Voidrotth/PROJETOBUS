const mongoose = require('mongoose');

// Uma viagem do relatório "Viagens" do Smart Report (ou, se improdutiva, a km improdutiva do veículo no dia).
const esquemaViagemRealizada = new mongoose.Schema({
  data: { type: String, required: true }, // dia operacional AAAA-MM-DD (viagem depois da meia-noite fica no dia anterior)
  linha: { type: String, default: null }, // nulo nas improdutivas
  prefixo: { type: String, required: true },
  atividade: { type: String, enum: ['normal', 'improdutiva'], required: true },
  sentido: { type: String, enum: ['ida', 'volta', null], default: null },
  hora: { type: Number, required: true }, // hora do início (0 nas improdutivas)
  inicio: { type: Date, default: null },
  fim: { type: Date, default: null },
  kmProdutiva: { type: Number, required: true },
  kmImprodutiva: { type: Number, required: true },
  kmTotal: { type: Number, required: true },
  fonte: { type: String, required: true } // arquivo de onde veio (a emissão mais nova do dia)
}, { versionKey: false });

esquemaViagemRealizada.index({ data: 1, prefixo: 1, atividade: 1, inicio: 1 }, { unique: true });
esquemaViagemRealizada.index({ data: 1, linha: 1 });

module.exports = mongoose.model('ViagemRealizada', esquemaViagemRealizada, 'viagensrealizadas');
