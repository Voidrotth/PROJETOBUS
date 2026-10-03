const mongoose = require('mongoose');

// Layouts de tabela que a assinatura não reconheceu e a IA mapeou (já validados contra os dados).
// Na próxima leitura do mesmo layout o mapa vem daqui, sem chamar a IA de novo.
const esquemaMapeamentoIA = new mongoose.Schema({
  assinatura: { type: String, required: true, unique: true }, // título | colunas
  tipo: { type: String, required: true },
  mapa: { type: Object, required: true }, // campo -> nome da coluna
  modelo: String
}, { timestamps: true });

module.exports = mongoose.model('MapeamentoIA', esquemaMapeamentoIA);
