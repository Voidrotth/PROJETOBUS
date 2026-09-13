const express = require('express');
const roteador = express.Router();
const Importacao = require('../modelos/Importacao');
const Operacao = require('../modelos/Operacao');

// GET /api/importacoes
// Lista importações com filtro opcional por status
roteador.get('/', async (req, res) => {
  try {
    const { status } = req.query;
    const filtro = status ? { status } : {};
    const importacoes = await Importacao.find(filtro).sort({ createdAt: -1 });
    res.json(importacoes);
  } catch (erro) {
    console.error('Erro ao buscar importações:', erro);
    res.status(500).json({ erro: 'Erro ao buscar importações' });
  }
});

// GET /api/importacoes/:id
// Retorna uma importação pelo ID
roteador.get('/:id', async (req, res) => {
  try {
    const importacao = await Importacao.findById(req.params.id);
    if (!importacao) {
      return res.status(404).json({ erro: 'Importação não encontrada' });
    }
    res.json(importacao);
  } catch (erro) {
    console.error('Erro ao buscar importação:', erro);
    res.status(500).json({ erro: 'Erro ao buscar importação' });
  }
});

// PUT /api/importacoes/:id
// Edita os dados extraídos de uma importação pendente
roteador.put('/:id', async (req, res) => {
  try {
    const importacao = await Importacao.findById(req.params.id);
    if (!importacao) {
      return res.status(404).json({ erro: 'Importação não encontrada' });
    }
    if (importacao.status !== 'pendente') {
      return res.status(400).json({ erro: 'Somente importações pendentes podem ser editadas' });
    }

    // Mescla os dados existentes com os novos
    const dadosAtualizados = req.body.dadosExtraidos || req.body;
    importacao.dadosExtraidos = { ...importacao.dadosExtraidos.toObject(), ...dadosAtualizados };
    await importacao.save();

    res.json(importacao);
  } catch (erro) {
    console.error('Erro ao atualizar importação:', erro);
    res.status(500).json({ erro: 'Erro ao atualizar importação' });
  }
});

// PATCH /api/importacoes/:id/confirmar
// Confirma a importação e cria a operação no banco
roteador.patch('/:id/confirmar', async (req, res) => {
  try {
    const importacao = await Importacao.findById(req.params.id);
    if (!importacao) {
      return res.status(404).json({ erro: 'Importação não encontrada' });
    }
    if (importacao.status !== 'pendente') {
      return res.status(400).json({ erro: 'Importação já foi processada' });
    }

    // Campos obrigatórios da operação precisam estar preenchidos antes de confirmar
    const dados = importacao.dadosExtraidos.toObject();
    const obrigatorios = { linha: 'linha', veiculo: 'veículo', motorista: 'motorista' };
    const faltando = Object.keys(obrigatorios)
      .filter(campo => !String(dados[campo] ?? '').trim())
      .map(campo => obrigatorios[campo]);
    if (faltando.length) {
      return res.status(400).json({
        erro: `Preencha os campos obrigatórios antes de confirmar: ${faltando.join(', ')}`,
        camposFaltando: faltando
      });
    }

    // Criar operação confirmada a partir dos dados extraídos
    const operacao = new Operacao({
      linha: dados.linha || '',
      veiculo: dados.veiculo || '',
      motorista: dados.motorista || '',
      cobrador: dados.cobrador || '',
      dataOperacao: dados.dataOperacao || new Date(),
      horarioSaida: dados.horarioSaida || '',
      horarioRecolhimento: dados.horarioRecolhimento || '',
      kmInicial: dados.kmInicial || 0,
      kmFinal: dados.kmFinal || 0,
      passageiros: dados.passageiros || 0,
      viagens: dados.viagens || 0,
      ocorrencias: dados.ocorrencias || '',
      origem: importacao.origem,
      importacaoId: importacao._id
    });

    await operacao.save();

    // Atualizar status da importação
    importacao.status = 'confirmado';
    await importacao.save();

    console.log(`Importação confirmada: ${importacao._id} → Operação: ${operacao._id}`);

    res.json({
      mensagem: 'Importação confirmada com sucesso',
      operacao
    });
  } catch (erro) {
    console.error('Erro ao confirmar importação:', erro);
    res.status(500).json({ erro: 'Erro ao confirmar importação' });
  }
});

// PATCH /api/importacoes/:id/rejeitar
// Rejeita a importação
roteador.patch('/:id/rejeitar', async (req, res) => {
  try {
    const importacao = await Importacao.findById(req.params.id);
    if (!importacao) {
      return res.status(404).json({ erro: 'Importação não encontrada' });
    }
    if (importacao.status !== 'pendente') {
      return res.status(400).json({ erro: 'Importação já foi processada' });
    }

    importacao.status = 'rejeitado';
    await importacao.save();

    console.log(`Importação rejeitada: ${importacao._id}`);

    res.json({ mensagem: 'Importação rejeitada' });
  } catch (erro) {
    console.error('Erro ao rejeitar importação:', erro);
    res.status(500).json({ erro: 'Erro ao rejeitar importação' });
  }
});

module.exports = roteador;
