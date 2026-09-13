const { ImapFlow } = require('imapflow');
const { simpleParser } = require('mailparser');
const { convert } = require('html-to-text');
const { registrarEmailRecebido } = require('./servicoEmail');

// Sem EMAIL_USUARIO no .env a leitura da caixa de entrada fica desligada
const leitorHabilitado = Boolean(process.env.EMAIL_USUARIO && process.env.EMAIL_SENHA);
const INTERVALO_MS = (Number(process.env.EMAIL_INTERVALO_SEGUNDOS) || 60) * 1000;

// Remetentes automáticos (alertas do Google etc.) que não são relatórios de operação
const REMETENTES_IGNORADOS = (process.env.EMAIL_REMETENTES_IGNORADOS ||
  'no-reply@accounts.google.com,no-reply@google.com,mailer-daemon@googlemail.com')
  .split(',')
  .map(r => r.trim().toLowerCase())
  .filter(Boolean);

let temporizador;
let verificando = false;

// Converte HTML em texto (tags e acentos como &iacute;) quando o e-mail não tem versão em texto puro
function htmlParaTexto(html) {
  return convert(html, { wordwrap: false });
}

// Conecta na caixa de entrada, registra os e-mails não lidos e marca como lidos
async function verificarCaixaEmail() {
  if (verificando) return;
  verificando = true;

  const cliente = new ImapFlow({
    host: process.env.EMAIL_IMAP_HOST || 'imap.gmail.com',
    port: Number(process.env.EMAIL_IMAP_PORTA) || 993,
    secure: true,
    auth: { user: process.env.EMAIL_USUARIO, pass: process.env.EMAIL_SENHA },
    logger: false
  });

  try {
    await cliente.connect();
    const trava = await cliente.getMailboxLock('INBOX');
    try {
      const naoLidos = (await cliente.search({ seen: false }, { uid: true })) || [];
      for (const uid of naoLidos) {
        const mensagem = await cliente.fetchOne(uid, { source: true }, { uid: true });
        const email = await simpleParser(mensagem.source);
        const texto = (email.text || htmlParaTexto(email.html || '')).trim();
        const remetente = (email.from?.value?.[0]?.address || email.from?.text || '').toLowerCase();

        if (REMETENTES_IGNORADOS.includes(remetente)) {
          console.log(`E-mail ignorado (remetente automático): ${remetente} | ${email.subject || '(sem assunto)'}`);
        } else if (texto) {
          await registrarEmailRecebido({ remetente, assunto: email.subject, texto });
        } else {
          console.warn(`E-mail sem texto ignorado: ${email.subject || '(sem assunto)'}`);
        }

        // Só marca como lido depois de salvar, para não perder e-mail em caso de erro
        await cliente.messageFlagsAdd(uid, ['\\Seen'], { uid: true });
      }
    } finally {
      trava.release();
    }
    await cliente.logout();
  } catch (erro) {
    console.error('Erro ao ler caixa de e-mail:', erro.responseText || erro.message);
    cliente.close();
  } finally {
    verificando = false;
  }
}

function iniciarLeitorCaixaEmail() {
  if (!leitorHabilitado) {
    console.log('Leitura de e-mail desabilitada (EMAIL_USUARIO/EMAIL_SENHA não definidos).');
    return;
  }
  console.log(`Lendo a caixa de ${process.env.EMAIL_USUARIO} a cada ${INTERVALO_MS / 1000}s`);
  verificarCaixaEmail();
  temporizador = setInterval(verificarCaixaEmail, INTERVALO_MS);
}

function pararLeitorCaixaEmail() {
  if (temporizador) clearInterval(temporizador);
}

module.exports = { iniciarLeitorCaixaEmail, pararLeitorCaixaEmail, verificarCaixaEmail };
