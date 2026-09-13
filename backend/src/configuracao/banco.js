const dns = require('dns');
const mongoose = require('mongoose');

// DNS públicos usados quando o DNS local não responde consultas SRV (mongodb+srv://)
const DNS_PUBLICOS = ['8.8.8.8', '1.1.1.1'];

const conectarBanco = async () => {
  const uri = process.env.MONGODB_URI;

  if (!uri || uri.includes('<db_username>') || uri.includes('<db_password>')) {
    console.error('Erro: defina MONGODB_URI no .env com usuário e senha reais do MongoDB Atlas');
    process.exit(1);
  }

  try {
    await mongoose.connect(uri);
    console.log('MongoDB conectado com sucesso');
  } catch (erro) {
    if (erro.message.includes('querySrv')) {
      // DNS local não responde consultas SRV: tenta de novo com DNS público
      dns.setServers(DNS_PUBLICOS);
      try {
        await mongoose.connect(uri);
        console.log('MongoDB conectado com sucesso');
        return;
      } catch (erroNovo) {
        erro = erroNovo;
      }
    }
    console.error('Erro ao conectar MongoDB:', erro.message);
    process.exit(1);
  }
};

module.exports = conectarBanco;
