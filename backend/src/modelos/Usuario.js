const mongoose = require('mongoose');

// Usuários do sistema: administradores (painel) e motoristas (aplicativo)
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
    enum: ['admin', 'motorista'],
    default: 'motorista'
  },
  telefone: {
    type: String,
    default: ''
  },
  cnh: {
    type: String,
    default: ''
  },
  ativo: {
    type: Boolean,
    default: true
  }
}, { timestamps: true });

module.exports = mongoose.model('Usuario', esquemaUsuario);
