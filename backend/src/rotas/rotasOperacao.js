const express = require('express');
const roteador = express.Router();
const Operacao = require('../modelos/Operacao');

// POST /api/operacoes
// Cadastro manual de operação
roteador.post('/', async (req, res) => {
  try {
    const { linha, veiculo, motorista, dataOperacao } = req.body;

    // Validar campos obrigatórios
    if (!linha || !veiculo || !motorista || !dataOperacao) {
      return res.status(400).json({
        erro: 'Campos obrigatórios: linha, veiculo, motorista, dataOperacao'
      });
    }

    const operacao = new Operacao({
      ...req.body,
      origem: 'manual'
    });

    await operacao.save();

    console.log(`Operação manual cadastrada: ${operacao._id}`);

    res.status(201).json(operacao);
  } catch (erro) {
    console.error('Erro ao cadastrar operação:', erro);
    res.status(500).json({ erro: 'Erro ao cadastrar operação' });
  }
});

// GET /api/operacoes
// Lista operações com filtros opcionais
roteador.get('/', async (req, res) => {
  try {
    const { linha, dataInicio, dataFim } = req.query;
    const filtro = {};

    if (linha) {
      filtro.linha = { $regex: linha, $options: 'i' };
    }

    if (dataInicio || dataFim) {
      filtro.dataOperacao = {};
      if (dataInicio) filtro.dataOperacao.$gte = new Date(dataInicio);
      if (dataFim) filtro.dataOperacao.$lte = new Date(dataFim);
    }

    const operacoes = await Operacao.find(filtro).sort({ createdAt: -1 });
    res.json(operacoes);
  } catch (erro) {
    console.error('Erro ao buscar operações:', erro);
    res.status(500).json({ erro: 'Erro ao buscar operações' });
  }
});

module.exports = roteador;
