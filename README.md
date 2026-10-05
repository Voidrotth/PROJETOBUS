# PROJETOBUS: Dashboard de Operação de Transporte (SEMOB-SCS)

Painel da Secretaria de Mobilidade Urbana de São Caetano do Sul (SEMOB) que substitui os relatórios
estáticos recebidos por e-mail.

- **Painel administrativo** (navegador, computador ou celular): a tela **Visão Geral** mostra
  quilometragem, viagens, passageiros pagantes, passageiros não pagantes e informações financeiras, por
  período **diário, semanal, quinzenal ou mensal**, com gráficos e comparação com o período anterior.
- **Motorista** (celular): entra com a matrícula, informa placa, linha e hodômetro e transmite a
  localização do ônibus.

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
| cloudflared | acessar pelo celular (opcional) | https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ |

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

As outras variáveis (`IA_MODELO`, `FUSO_OPERACAO`, `DADOS_PASTA`) já vêm prontas.

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
npm run criar-usuario -- <usuário> <senha> "<nome>" <papel>
```

- `<papel>` só aceita **`admin`** (painel) ou **`motorista`** (app do motorista).
- A senha precisa ter pelo menos 6 caracteres.
- O usuário não pode repetir. Se aparecer `Já existe um usuário com este e-mail`, escolha outro nome de
  usuário.

## Administrador (painel)

```
npm run criar-usuario -- pedro "minhasenha" "Pedro" admin
```

No painel, o login será `pedro` com a senha `minhasenha`.

## Motorista

```
npm run criar-usuario -- motorista1 "senha123" "Motorista Teste" motorista
```

No app, o motorista entra com `motorista1` e `senha123`.

O script não grava a matrícula. Num motorista de verdade, a matrícula importa: é a mesma dos relatórios
do Smart Report e liga as viagens do app aos relatórios. O cadastro com matrícula era feito pela aba
**Frota** do painel antigo, que hoje está fora do menu (veja "Telas fora do menu").

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

# Usar o painel (Visão Geral)

1. Abra **http://localhost:3000** e entre com o usuário administrador.
2. Em **Período**, escolha **Diário**, **Semanal** (segunda a domingo), **Quinzenal** (dias 1 a 15 e
   16 ao fim do mês) ou **Mensal**.
3. Use as setas **◀ ▶** para ir aos períodos anteriores.
   - O painel abre no período mais recente que tem dados.
   - A data dos dados mais recentes aparece em "dados até ...".

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

O painel se atualiza sozinho quando relatórios novos são processados. O botão ↻ também atualiza.

No celular, os cards ficam em duas colunas e a navegação vai para uma barra na parte de baixo.

---

# Importar os relatórios do Smart Report

1. Crie a pasta `PROJETOBUS\dados\`. Ela não vem no repositório porque os dados são reais.
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

# Acessar como motorista

1. Na tela de login, toque em **Sou motorista**.
2. Entre com o usuário (ou a matrícula) e a senha do motorista.
3. Preencha:
   - **Placa:** `ABC1234` ou Mercosul `ABC1D23`. Um ônibus ainda não cadastrado entra sozinho.
   - **Linha:** 2 dígitos, ex.: `01`.
   - **Km do hodômetro.**
4. Toque em **INICIAR E TRANSMITIR LOCALIZAÇÃO** e permita o acesso à localização.
5. Ao terminar, toque em encerrar e informe o **km do hodômetro no final**.

No computador, a localização funciona em `http://localhost`. No celular, só funciona por um endereço
**https** (veja a próxima seção).

---

# Acessar pelo celular

O navegador do celular só libera o GPS em endereços **https**. Com o backend rodando, abra **outro**
PowerShell (o do `npm run dev` precisa continuar aberto) e rode:

```
cloudflared tunnel --url http://localhost:3000
```

1. No terminal aparece um endereço `https://...trycloudflare.com`. Copie esse endereço.
2. Abra o endereço no navegador do celular (Safari no iPhone, Chrome no Android).
3. Entre como administrador (painel) ou toque em **Sou motorista**.

O endereço muda toda vez que o comando é iniciado. **Enquanto ele estiver rodando, o sistema fica
acessível pela internet.** Feche o terminal (ou `Ctrl+C`) quando terminar os testes.

No iPhone, mantenha a tela ligada durante a transmissão: o Safari para o GPS quando a tela apaga.

---

# Telas fora do menu

O menu segue o wireframe do Figma e hoje tem só a **Visão Geral**. As telas do painel antigo continuam
no código, em `frontend\lib\telas\`, mas não aparecem no menu:

| Tela | O que faz | Enquanto isso, use |
|---|---|---|
| Frota (`frota\tela_cadastros_frota.dart`) | cadastro de ônibus e de motoristas com matrícula | `npm run criar-usuario` |
| Ao vivo (`frota\tela_frota_ao_vivo.dart`) | mapa dos ônibus em tempo real | — |
| Enviar dados (`tela_envio_dados.dart`) | envio dos relatórios pelo navegador | `npm run importar-dados` |
| Verificação (`tela_verificacao.dart`) | conferência detalhada dos relatórios, feriados, exportação Excel/CSV | — |
| Operação (`tela_operacao.dart`) | viagens por linha, horário e veículo | — |

Para trazer uma delas de volta, acrescente uma entrada na lista `_abasDoPainel` em
`frontend\lib\main.dart`, por exemplo:

```dart
ItemNavegacao(rotulo: 'Ao vivo', icone: Icons.map_outlined, construir: () => const TelaFrotaAoVivo()),
```

Não esqueça de importar o arquivo da tela no topo do `main.dart`.

---

# Estrutura do frontend

| Pasta | Conteúdo |
|---|---|
| `frontend\lib\tema\` | design system do Figma: cores, fontes (Fjalla One, Inter, Space Mono), espaçamentos e breakpoints |
| `frontend\lib\visao_geral\` | tela Visão Geral, cálculo dos períodos e dos indicadores |
| `frontend\lib\componentes\` | estrutura de navegação, logo e gráfico diário |
| `frontend\lib\servicos\` | comunicação com a API e sessão do usuário |
| `frontend\lib\telas\motorista\` | app do motorista |
| `frontend\assets\fonts\` | arquivos das fontes (o painel funciona sem internet) |

O logo é um texto provisório. Para usar a imagem oficial, coloque o arquivo em `frontend\assets\` e
troque o conteúdo de `frontend\lib\componentes\logo.dart` por um `Image.asset`.

---

# Testes

Backend (leitura dos relatórios), na pasta `PROJETOBUS\backend`:

```
npm test
```

Frontend (períodos, cálculo dos indicadores e telas), na pasta `PROJETOBUS\frontend`:

```
flutter test
```

Simular um ônibus andando, na pasta `PROJETOBUS\backend`, com o usuário e a senha de um administrador:

```
npm run simular-viagem -- pedro "minhasenha" 5 02
```

O comando põe um ônibus de teste (prefixo 9999) andando por 5 minutos na linha 02. O mapa que mostra
esse ônibus fica na tela **Ao vivo**, hoje fora do menu (veja "Telas fora do menu"). `Ctrl+C` encerra
antes.

---

# PM2 (opcional)

O PM2 mantém o sistema rodando em segundo plano, sem precisar deixar terminais abertos. Instalação
(uma vez só):

```
npm install -g pm2
```

Para iniciar, a partir da pasta `PROJETOBUS`:

```
pm2 start backend/src/servidor.js --name projetobus-backend --cwd backend
pm2 start "C:/Program Files (x86)/cloudflared/cloudflared.exe" --name projetobus-tunel --interpreter none -- tunnel --no-autoupdate --url http://localhost:3000
```

O segundo comando usa o caminho onde o instalador do Windows coloca o `cloudflared`. Ajuste se ele
estiver em outra pasta.

Comandos do dia a dia:

| Comando | O que faz |
|---|---|
| `pm2 list` | mostra o que está rodando |
| `pm2 restart projetobus-backend` | reinicia o sistema (depois de mudar o `.env`, atualizar o projeto ou rodar `flutter build web` pela primeira vez) |
| `pm2 restart projetobus-tunel` | gera um novo endereço https para o celular |
| `pm2 logs projetobus-tunel --lines 50` | mostra o endereço https atual (linha com `trycloudflare.com`) |
| `pm2 logs projetobus-backend` | mostra os registros do backend |

---

# Acesso rápido

1. Baixar o projeto: `git clone https://github.com/Voidrotth/PROJETOBUS.git`
2. Instalar as dependências:
   `cd PROJETOBUS\backend` → `copy .env.example .env` → `npm install` →
   `cd ..\frontend` → `flutter pub get` → `flutter build web`
3. Configurar `PROJETOBUS\backend\.env` (`MONGODB_URI`, `JWT_SEGREDO` e `PORT`).
4. Criar um administrador: `cd ..\backend` → `npm run criar-usuario -- pedro "minhasenha" "Pedro" admin`
5. Iniciar o backend: `npm run dev`
6. Abrir **http://localhost:3000** (ou a porta do seu `.env`) e entrar com o administrador.
7. Para o celular, abrir outro PowerShell e rodar `cloudflared tunnel --url http://localhost:3000`.
8. Abrir no celular o link `https://...trycloudflare.com` que aparecer.
