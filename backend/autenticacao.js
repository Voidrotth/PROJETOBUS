const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const VALIDADE_TOKEN = '12h';

let segredo = process.env.JWT_SEGREDO;
if (!segredo) {
  // Sem segredo fixo, todo reinício do servidor desloga todo mundo
  segredo = crypto.randomBytes(32).toString('hex');
  console.warn('JWT_SEGREDO não definido no .env: usando um segredo temporário (logins caem ao reiniciar).');
}

function gerarToken(usuario) {
  return jwt.sign({ id: String(usuario._id), papel: usuario.papel, nome: usuario.nome }, segredo, {
    expiresIn: VALIDADE_TOKEN
  });
}

// Computador da SEMOB: fica ligado 24 h com o painel aberto, então entra com uma chave fixa
// (CHAVE_COMPUTADOR_SEMOB no .env) em vez do login de 12 h. O papel "computador" só lê os indicadores.
const resumo = texto => crypto.createHash('sha256').update(String(texto)).digest();
const chaveComputador = process.env.CHAVE_COMPUTADOR_SEMOB ? resumo(process.env.CHAVE_COMPUTADOR_SEMOB) : null;

// Lança erro se o token for inválido ou expirado
function lerToken(token) {
  if (chaveComputador && token && crypto.timingSafeEqual(resumo(token), chaveComputador)) return { papel: 'computador', nome: 'Computador da SEMOB' };
  return jwt.verify(token, segredo);
}

// Exige "Authorization: Bearer <token>" e coloca os dados do usuário em req.usuario
function autenticar(req, res, next) {
  const [tipo, token] = (req.headers.authorization || '').split(' ');
  if (tipo !== 'Bearer' || !token) {
    return res.status(401).json({ erro: 'Faça login para continuar' });
  }
  try {
    req.usuario = lerToken(token);
    next();
  } catch {
    res.status(401).json({ erro: 'Sessão expirada, faça login novamente' });
  }
}

function exigirPapel(...papeis) {
  return (req, res, next) => {
    if (!papeis.includes(req.usuario?.papel)) {
      return res.status(403).json({ erro: 'Acesso não permitido para este usuário' });
    }
    next();
  };
}

module.exports = { gerarToken, lerToken, autenticar, exigirPapel };
