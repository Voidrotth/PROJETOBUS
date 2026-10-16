// Cria um administrador direto no banco (útil para o primeiro acesso).
// Uso: npm run criar-usuario -- <usuário> <senha> "<nome>"
require('dotenv').config();
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const conectarBanco = require('./banco');
const Usuario = require('./Usuario');

async function principal() {
  const [email, senha, nome] = process.argv.slice(2);
  if (!email || !senha || !nome) {
    console.log('Uso: npm run criar-usuario -- <usuário> <senha> "<nome>"');
    process.exit(1);
  }
  if (senha.length < 6) {
    console.log('A senha precisa ter pelo menos 6 caracteres');
    process.exit(1);
  }

  await conectarBanco();
  const usuario = await Usuario.create({ email, nome, papel: 'admin', senhaHash: await bcrypt.hash(senha, 10) });
  console.log(`Usuário criado: ${usuario.email} (${usuario.papel})`);
  await mongoose.disconnect();
}

principal().catch(async erro => {
  console.error(erro.code === 11000 ? 'Já existe um usuário com este e-mail' : erro.message);
  await mongoose.disconnect();
  process.exit(1);
});
