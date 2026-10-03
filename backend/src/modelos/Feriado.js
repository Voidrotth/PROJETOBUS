const mongoose = require('mongoose');

// Feriados cadastrados pelo gestor: os relatórios do verificador não trazem calendário de feriados
const esquemaFeriado = new mongoose.Schema({
  data: { type: String, required: true, unique: true, match: /^\d{4}-\d{2}-\d{2}$/ }, // AAAA-MM-DD
  nome: { type: String, default: '', trim: true }
}, { timestamps: true });

module.exports = mongoose.model('Feriado', esquemaFeriado);
