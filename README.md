# PROJETOBUS: Dashboard de Operação de Transporte (SEMOB-SCS)

Painel da Secretaria de Mobilidade Urbana de São Caetano do Sul (SEMOB) que substitui os relatórios
estáticos recebidos por e-mail.

O dashboard foi feito para ficar aberto no **computador da SEMOB, ligado 24 horas** a uma tela grande, com o navegador em tela cheia: não tem botões. Ele mostra quilometragem,
viagens, passageiros pagantes, passageiros não pagantes e informações financeiras, com gráficos e
comparação com o período anterior, e troca sozinho entre **diário, semanal, quinzenal e mensal** a cada
1 minuto.

Um único endereço serve tudo: o backend (Node.js) entrega a API e o painel (Flutter Web). Os dados ficam
no MongoDB Atlas e vêm dos relatórios do **Smart Report**.

---

# O que instalar antes

Instale no Windows (uma vez só):

| Programa | Para quê | Onde baixar |
|---|---|---|
| Git | baixar o projeto | https://git-scm.com/download/win |
| Node.js 20 ou mais novo | rodar o backend | https://nodejs.org |
| Flutter (versão estável) | compilar o painel | https://docs.flutter.dev/get-started/install/windows/web |
| Google Chrome | rodar o painel em modo de desenvolvimento | https://www.google.com/chrome |

Depois de instalar, feche o PowerShell e abra de novo para os comandos serem reconhecidos.

---

# Como instalar

Abra o PowerShell na pasta onde quer guardar o projeto e rode:

```
git clone https://github.com/Voidrotth/PROJETOBUS.git
```

## Backend

```
cd PROJETOBUS\backend
copy .env.example .env
npm install
```

## Frontend (painel)

```
cd ..\frontend
flutter pub get
flutter build web
```

O `flutter build web` gera o painel na pasta `frontend\build\web`. O backend passa a mostrá-lo no
endereço do sistema.

---

# Configurar o `.env`

Abra **`PROJETOBUS\backend\.env`** no Bloco de Notas e preencha:

| Variável | O que colocar |
|---|---|
| `MONGODB_URI` | endereço do banco MongoDB Atlas com usuário e senha (peça ao responsável pelo projeto) |
| `JWT_SEGREDO` | um texto longo e aleatório (é o que mantém os logins válidos) |
| `OPENROUTER_API_KEY` | chave da OpenRouter (só é usada quando chega um relatório com colunas diferentes) |
| `PORT` | porta do sistema (padrão `3000`) |
| `CHAVE_COMPUTADOR_SEMOB` | um texto longo e aleatório: é a "senha" do computador da SEMOB, que entra sem login (veja "Abrir no computador da SEMOB") |

As outras variáveis (`IA_MODELO`, `DADOS_PASTA`) já vêm prontas.

- **Porta:** todos os endereços deste README usam a porta `3000`. Se você mudou o `PORT`, troque `3000`
  pela sua porta em todos eles.
- **Acesso ao banco:** o MongoDB Atlas só aceita conexões de IPs liberados. Peça ao responsável para
  liberar o seu IP em **Atlas → Network Access**.
- **Segurança:** nunca envie o arquivo `.env` para o GitHub (o `.gitignore` já impede).

---

# Criar os usuários

Todos os comandos abaixo são rodados **dentro da pasta `PROJETOBUS\backend`**. Fora dela, o npm dá o erro
`ENOENT ... package.json`.

O formato do comando é:

```
npm run criar-usuario -- <usuário> <senha> "<nome>"
```

- O usuário criado é sempre administrador. O dashboard só aceita administradores (e o computador da SEMOB, pela chave).
- A senha precisa ter pelo menos 6 caracteres.
- O usuário não pode repetir. Se aparecer `Já existe um usuário com este e-mail`, escolha outro nome de
  usuário.

## Administrador (painel)

```
npm run criar-usuario -- pedro "minhasenha" "Pedro"
```

No painel, o login será `pedro` com a senha `minhasenha`.

---

# Iniciar o sistema

Na pasta `PROJETOBUS\backend`:

```
npm run dev
```

Deixe esse terminal aberto. Quando aparecer `PROJETOBUS Backend rodando na porta ...`, abra no navegador:

**http://localhost:3000**

- **Painel não aparece:** o backend só mostra o painel se a pasta `frontend\build\web` já existia quando
  ele foi iniciado. Rode `flutter build web` e reinicie o backend (`Ctrl+C` e `npm run dev` de novo).
- **Mudou o código do frontend:** rode `flutter build web` de novo e recarregue a página. Não precisa
  reiniciar o backend.

## Modo de desenvolvimento do painel

Para mexer no frontend sem recompilar a cada mudança, deixe o backend rodando e, em **outro** PowerShell:

```
cd PROJETOBUS\frontend
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
```

O Chrome abre sozinho. Depois de alterar o código, aperte `r` no terminal para ver a mudança na hora.

---

# Abrir no computador da SEMOB

1. Preencha `CHAVE_COMPUTADOR_SEMOB` no `.env` e reinicie o backend.
2. No navegador do computador da SEMOB, abra:

   **http://ENDERECO_DO_SERVIDOR:3000/?semob=SUA_CHAVE**

3. Deixe o navegador em tela cheia (`F11`). Não precisa fazer login nem tocar em nada.

- A chave só deixa **ver** os indicadores: não envia relatórios nem altera nada.
- Quem tem o endereço com a chave vê o dashboard. Se ela vazar, troque `CHAVE_COMPUTADOR_SEMOB` e reinicie o backend.
- Sem a chave, o endereço abre o login, e um administrador vê a mesma tela.

# O que o painel mostra

A cada **1 minuto** a tela troca de período:
**Diário → Semanal** (segunda a domingo) **→ Quinzenal** (dias 1 a 15 e 16 ao fim do mês) **→ Mensal**.
Depois do mensal, o ciclo recomeça no **mês seguinte** com dados: abre em setembro e segue para julho,
agosto, setembro e assim por diante. Em cada mês, o diário mostra o último dia com dados daquele mês. Uma barra no topo mostra quanto falta para a próxima troca. O topo também mostra o
relógio, a data e até que dia vão os dados ("dados até ...").

Para mudar o tempo de cada período, use os botões **−** e **+** ao lado de "trocar a cada" (de 10 em
10 segundos, de 10 s a 10 min; o padrão é 60 s). A escolha fica salva no navegador do computador.

A tela mostra:

- **5 indicadores:** Quilometragem, Viagens, Passageiros Pagantes, Passageiros Não Pagantes e
  Informações Financeiras.
  - Cada um traz a variação contra o período anterior. No diário, a comparação é com o mesmo dia da
    semana anterior (segunda com segunda).
  - A variação compara a média por dia, para que meses de tamanhos diferentes e períodos ainda
    incompletos fiquem comparáveis.
  - Quando parte dos dias do período não tem dado, o card avisa (ex.: "dado em 10 de 30 dias").
- **4 gráficos:** passageiros por dia, cumprimento de viagens (total e por turno), quilometragem por dia
  e venda × validação de créditos (com o alerta de crédito circulante).
  - No diário, os gráficos mostram os 7 dias até o dia escolhido.

Quando faltar um dado, o painel mostra **"sem dado"**, nunca zero. Hoje faltam estes:

- **Receita de catraca (dinheiro e cartão):** não vem no Smart Report. Só entra por planilha CSV.
- **Cumprimento por turno:** só aparece se o relatório "Fator de Cumprimento de Viagem" foi importado.
  Sem ele, aparece só o total do período.

A tela se atualiza sozinha quando relatórios novos são processados e, de qualquer forma, a cada 5
minutos. Se o servidor cair, ela tenta de novo sozinha.

---

# Importar os relatórios do Smart Report

1. Crie a pasta `PROJETOBUS\esquecidos\dados\` (ou aponte `DADOS_PASTA` no `.env`). Ela não vem no repositório porque os dados são reais.
2. Coloque nela os arquivos HTML do Smart Report.
3. Na pasta `PROJETOBUS\backend`, rode:

```
npm run importar-dados
```

Para só conferir os arquivos, sem gravar nada no banco:

```
npm run importar-dados -- --conferir
```

---

# Telas fora do menu

O dashboard é só a **Visão Geral**. As telas do painel antigo continuam no código, em
`frontend\lib\telas\`, mas não aparecem:

| Tela | O que faz | Enquanto isso, use |
|---|---|---|
| Frota (`frota\tela_cadastros_frota.dart`) | cadastro de ônibus | — |
| Enviar dados (`tela_envio_dados.dart`) | envio dos relatórios pelo navegador | `npm run importar-dados` |
| Verificação (`tela_verificacao.dart`) | conferência detalhada dos relatórios, feriados, exportação Excel/CSV | — |
| Operação (`tela_operacao.dart`) | viagens por linha, horário e veículo | — |

---

# Estrutura do frontend

| Pasta | Conteúdo |
|---|---|
| `frontend\lib\tema\` | design system do Figma: cores, fontes (Fjalla One, Inter, Space Mono), espaçamentos e breakpoints |
| `frontend\lib\visao_geral\` | tela Visão Geral, cálculo dos períodos e dos indicadores |
| `frontend\lib\componentes\` | logo e gráfico diário |
| `frontend\lib\servicos\` | comunicação com a API e sessão do usuário |
| `frontend\assets\fonts\` | arquivos das fontes (o painel funciona sem internet) |

O logo é um texto provisório. Para usar a imagem oficial, coloque o arquivo em `frontend\assets\` e
troque o conteúdo de `frontend\lib\componentes\logo.dart` por um `Image.asset`.

---

# Testes

Os testes ficam fora do projeto, em `esquecidos/backend-test/` e `esquecidos/frontend-test/`.
Para rodar, copie de volta para `backend/test/` / `frontend/test/` e use `node --test test/` ou `flutter test`.

---

# PM2 (opcional)

O PM2 mantém o sistema rodando em segundo plano, sem precisar deixar terminais abertos. Instalação
(uma vez só):

```
npm install -g pm2
```

Para iniciar, a partir da pasta `PROJETOBUS`:

```
pm2 start backend/servidor.js --name projetobus --cwd backend
```

Comandos do dia a dia:

| Comando | O que faz |
|---|---|
| `pm2 list` | mostra o que está rodando |
| `pm2 restart projetobus` | reinicia o sistema (depois de mudar o `.env`, atualizar o projeto ou rodar `flutter build web` pela primeira vez) |
| `pm2 logs projetobus` | mostra os registros do backend |

---

# Acesso rápido

1. Baixar o projeto: `git clone https://github.com/Voidrotth/PROJETOBUS.git`
2. Instalar as dependências:
   `cd PROJETOBUS\backend` → `copy .env.example .env` → `npm install` →
   `cd ..\frontend` → `flutter pub get` → `flutter build web`
3. Configurar `PROJETOBUS\backend\.env` (`MONGODB_URI`, `JWT_SEGREDO`, `CHAVE_COMPUTADOR_SEMOB` e `PORT`).
4. Criar um administrador: `cd ..\backend` → `npm run criar-usuario -- pedro "minhasenha" "Pedro"`
5. Iniciar o backend: `npm run dev`
6. No computador da SEMOB, abrir **http://ENDERECO_DO_SERVIDOR:3000/?semob=SUA_CHAVE** em tela cheia (`F11`).
