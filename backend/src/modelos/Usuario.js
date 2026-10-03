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
  // Matrícula do motorista: é ela que aparece nos relatórios do Smart Report (coluna "Motorista")
  // e é o login do motorista no app
  matricula: {
    type: String,
    default: '',
    trim: true
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

// Matrícula única quando preenchida (admins ficam sem)
esquemaUsuario.index({ matricula: 1 }, { unique: true, partialFilterExpression: { matricula: { $gt: '' } } });

module.exports = mongoose.model('Usuario', esquemaUsuario);
