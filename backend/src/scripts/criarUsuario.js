// Cria um usuário direto no banco (útil para o primeiro administrador).
// Uso: npm run criar-usuario -- <email> <senha> "<nome>" [admin|motorista]
require('dotenv').config();
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const conectarBanco = require('../configuracao/banco');
const Usuario = require('../modelos/Usuario');

async function principal() {
  const [email, senha, nome, papel = 'admin'] = process.argv.slice(2);
  if (!email || !senha || !nome) {
    console.log('Uso: npm run criar-usuario -- <email> <senha> "<nome>" [admin|motorista]');
    process.exit(1);
  }
  if (senha.length < 6) {
    console.log('A senha precisa ter pelo menos 6 caracteres');
    process.exit(1);
  }

  await conectarBanco();
  const usuario = await Usuario.create({ email, nome, papel, senhaHash: await bcrypt.hash(senha, 10) });
  console.log(`Usuário criado: ${usuario.email} (${usuario.papel})`);
  await mongoose.disconnect();
}

principal().catch(async erro => {
  console.error(erro.code === 11000 ? 'Já existe um usuário com este e-mail' : erro.message);
  await mongoose.disconnect();
  process.exit(1);
});
