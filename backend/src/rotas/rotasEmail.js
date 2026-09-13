const express = require('express');
const roteador = express.Router();
const { registrarEmailRecebido } = require('../servicos/servicoEmail');


// Recebe e-mail via webhook, salva a importação e envia para processamento da IA

roteador.post('/webhook', async (req, res) => {
  try {
    const { from, subject, text } = req.body;

    if (!text) {
      return res.status(400).json({ erro: 'Campo "text" é obrigatório' });
    }

    const { importacao, viaKafka } = await registrarEmailRecebido({
      remetente: from,
      assunto: subject,
      texto: text
    });

    res.status(201).json({
      mensagem: viaKafka
        ? 'E-mail recebido. Dados sendo extraídos pela IA. Pendente de revisão.'
        : 'E-mail processado com sucesso. Pendente de revisão.',
      importacao
    });
  } catch (erro) {
    console.error('Erro ao processar e-mail:', erro);
    res.status(500).json({ erro: 'Erro ao processar e-mail' });
  }
});

module.exports = roteador;
