// Envolve um handler async e converte os erros conhecidos em respostas HTTP
function rota(handler) {
  return async (req, res) => {
    try {
      await handler(req, res);
    } catch (erro) {
      if (erro.status) {
        return res.status(erro.status).json({ erro: erro.message, ...erro.dados });
      }
      if (erro.name === 'CastError') {
        return res.status(404).json({ erro: 'Registro não encontrado' });
      }
      if (erro.name === 'ValidationError') {
        return res.status(400).json({ erro: erro.message });
      }
      if (erro.code === 11000) {
        const campo = Object.keys(erro.keyValue || {})[0] || 'campo';
        return res.status(409).json({ erro: `Já existe um registro com este ${campo}` });
      }
      console.error(`Erro em ${req.method} ${req.originalUrl}:`, erro);
      res.status(500).json({ erro: 'Erro interno do servidor' });
    }
  };
}

class ErroHttp extends Error {
  constructor(status, mensagem) {
    super(mensagem);
    this.status = status;
  }
}

module.exports = { rota, ErroHttp };
