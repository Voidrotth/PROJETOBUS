const express = require('express');
const roteador = express.Router();
const Operacao = require('../modelos/Operacao');

// GET /api/painel/resumo
// Retorna dados agregados para o painel
roteador.get('/resumo', async (req, res) => {
  try {
    // Total de operações
    const totalOperacoes = await Operacao.countDocuments();

    // Agregações gerais
    const agregacao = await Operacao.aggregate([
      {
        $group: {
          _id: null,
          totalPassageiros: { $sum: { $ifNull: ['$passageiros', 0] } },
          totalViagens: { $sum: { $ifNull: ['$viagens', 0] } },
          totalKm: {
            $sum: {
              $subtract: [
                { $ifNull: ['$kmFinal', 0] },
                { $ifNull: ['$kmInicial', 0] }
              ]
            }
          }
        }
      }
    ]);

    // Operações agrupadas por linha
    const operacoesPorLinha = await Operacao.aggregate([
      {
        $group: {
          _id: '$linha',
          total: { $sum: 1 }
        }
      },
      { $sort: { total: -1 } }
    ]);

    // Últimas ocorrências (excluindo vazias)
    const ultimasOcorrencias = await Operacao.find({
      ocorrencias: { $nin: [null, '', 'Nenhuma', 'nenhuma', 'N/A'] }
    })
      .select('linha veiculo dataOperacao ocorrencias')
      .sort({ createdAt: -1 })
      .limit(10);

    const resumo = agregacao[0] || {
      totalPassageiros: 0,
      totalViagens: 0,
      totalKm: 0
    };

    res.json({
      totalOperacoes,
      totalPassageiros: resumo.totalPassageiros,
      totalViagens: resumo.totalViagens,
      totalKm: resumo.totalKm,
      operacoesPorLinha,
      ultimasOcorrencias
    });
  } catch (erro) {
    console.error('Erro ao gerar resumo:', erro);
    res.status(500).json({ erro: 'Erro ao gerar resumo do painel' });
  }
});

module.exports = roteador;
