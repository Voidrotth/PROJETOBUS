const mongoose = require('mongoose');

// Administradores do painel (a TV entra pela chave TV_CHAVE, sem usuário)
const esquemaUsuario = new mongoose.Schema({
  nome: {
    type: String,
    required: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  senhaHash: {
    type: String,
    required: true,
    select: false
  },
  papel: {
    type: String,
    enum: ['admin'],
    default: 'admin'
  },
  ativo: {
    type: Boolean,
    default: true
  }
}, { timestamps: true });

module.exports = mongoose.model('Usuario', esquemaUsuario);
