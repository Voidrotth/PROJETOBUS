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
  },
  // Relação com o motorista no Fleetbase (só para papel "motorista")
  fleetbaseId: {
    type: String,
    default: null
  },
  fleetbasePendente: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

module.exports = mongoose.model('Usuario', esquemaUsuario);
