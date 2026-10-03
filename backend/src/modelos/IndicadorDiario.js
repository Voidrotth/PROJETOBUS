const mongoose = require('mongoose');

const numero = { type: Number, default: null };

// Um registro por data com os indicadores dos arquivos enviados pelo gestor (pasta dados/).
// "linha" nulo = agregado geral do sistema; para detalhar por linha no futuro basta
// gravar registros com a linha preenchida (o índice único já é data + linha).
const esquemaIndicadorDiario = new mongoose.Schema({
  data: { type: String, required: true }, // AAAA-MM-DD
  linha: { type: String, default: null },
  diaSemana: String,
  // Seg–sex com menos viagens programadas que os dias úteis vizinhos (candidato a feriado; ver modelo Feriado)
  programacaoReduzida: { type: Boolean, default: false },

  // Operação (Resumo Geral)
  veiculos: numero,
  maxVeiculosFaixa: numero,
  viagensProgramadas: numero,
  viagensRealizadas: numero,
  viagensNaoCumpridas: numero,
  kmProdutiva: numero,
  kmImprodutiva: numero,
  kmTotal: numero,

  // Fator de Cumprimento de Viagem (os limites de horário dos turnos não vêm no relatório)
  manhaProgramadas: numero,
  manhaRealizadas: numero,
  tardeProgramadas: numero,
  tardeRealizadas: numero,
  noiteProgramadas: numero,
  noiteRealizadas: numero,

  // Passageiros do Sistema
  catraca: numero,
  antecipados: numero,
  naoPagantes: numero,
  passageiros: numero,

  // Venda x Utilização (R$)
  vendas: numero,
  utilizacao: numero,
  circulante: numero,

  // Saldo de créditos do sistema (R$)
  transferidos: numero,
  saldoFinal: numero,

  // Receita de catraca (R$): não vem no Smart Report, só por planilha CSV enviada pelo gestor
  receitaCatracaDinheiro: numero,
  receitaCatracaCartao: numero,

  // Arquivo de onde veio cada grupo de indicadores
  fontes: { operacao: String, turnos: String, passageiros: String, creditos: String, saldo: String, planilha: String },
  // Valores que mudaram entre uma emissão e outra do relatório
  revisoes: [{ _id: false, campo: String, de: Number, para: Number, arquivoAnterior: String, arquivo: String }]
}, { timestamps: true });

esquemaIndicadorDiario.index({ data: 1, linha: 1 }, { unique: true });

module.exports = mongoose.model('IndicadorDiario', esquemaIndicadorDiario);
