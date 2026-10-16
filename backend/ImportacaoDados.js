const mongoose = require('mongoose');

// Registro de cada leitura da pasta dados/: o que foi lido e o resultado das conferências
const esquemaImportacaoDados = new mongoose.Schema({
  arquivos: [{
    _id: false,
    arquivo: String,
    relatorios: [String],
    registros: Number,
    geradoEm: String,
    inicio: String,
    fim: String,
    uso: String, // indicadores | conferencia | nao_utilizado | duplicado | erro
    identificacao: String, // assinatura | ia | planilha (como o tipo de cada relatório foi reconhecido)
    erro: String
  }],
  conferencias: [{
    _id: false,
    descricao: String,
    verificados: Number,
    divergencias: [{ _id: false, data: String, arquivo: String, detalhe: String }]
  }],
  // Linhas de ônibus que aparecem nos relatórios (ainda não detalhadas no painel)
  linhas: [String]
}, { timestamps: true });

module.exports = mongoose.model('ImportacaoDados', esquemaImportacaoDados);
