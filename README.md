# PROJETOBUS

Sistema de acompanhamento da operação de ônibus:

- **Painel administrativo** (navegador): indicadores dos relatórios do Smart Report, mapa dos ônibus ao vivo,
  km e combustível por ônibus, cadastro da frota e dos motoristas.
- **Motorista** (celular): entra com a matrícula, informa placa, linha e hodômetro e transmite a localização.

Tudo é servido por um único endereço: o backend (Node.js) entrega a API e o painel (Flutter Web).
Os dados ficam no MongoDB Atlas.

---

# O que instalar antes

Instale no Windows (uma vez só):

| Programa | Para quê | Onde baixar |
|---|---|---|
| Git | baixar o projeto | https://git-scm.com/download/win |
| Node.js 20 ou mais novo | rodar o backend | https://nodejs.org |
| Flutter (versão estável) | compilar o painel | https://docs.flutter.dev/get-started/install/windows/web |
| cloudflared | acessar pelo celular (opcional) | https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ |

Depois de instalar, feche e abra o terminal (PowerShell) de novo para os comandos serem reconhecidos.

---

# Como instalar o PROJETOBUS

Abra o PowerShell na pasta onde quer guardar o projeto (por exemplo, a Área de Trabalho) e rode:

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

Continuando no mesmo terminal:

```
cd ..\frontend
flutter pub get
flutter build web
```

O `flutter build web` gera o painel; o backend passa a mostrá-lo no endereço do sistema.

---

# Configurar o sistema

Abra o arquivo **`PROJETOBUS\backend\.env`** no Bloco de Notas e preencha:

| Variável | O que colocar |
|---|---|
| `MONGODB_URI` | endereço do banco MongoDB Atlas com usuário e senha (peça ao responsável pelo projeto) |
| `JWT_SEGREDO` | um texto longo e aleatório (é o que mantém os logins válidos) |
| `OPENROUTER_API_KEY` | chave da OpenRouter (só é usada quando chega um relatório com colunas diferentes) |
| `PORT` | porta do sistema; deixe `3000` |

As outras variáveis (`IA_MODELO`, `FUSO_OPERACAO`, `DADOS_PASTA`) já vêm prontas.

O MongoDB Atlas só aceita conexões de IPs liberados: peça ao responsável para liberar o seu IP em
**Atlas → Network Access**.

Nunca envie o arquivo `.env` para o GitHub (o `.gitignore` já impede).

## Criar o administrador

Só é necessário se o banco ainda **não tiver** um administrador. Na pasta `PROJETOBUS\backend`:

```
npm run criar-usuario -- SEMOB "SENHA_DO_ADMIN" "Administrador" admin
```

Troque `SENHA_DO_ADMIN` pela senha desejada (mínimo de 6 caracteres). O login do painel será `SEMOB`.

## Cadastrar motoristas

O motorista entra no app com a **matrícula** (a mesma dos relatórios) e uma senha. Para cadastrar:
entre no painel como administrador → aba **Frota** → **Motoristas** → adicionar → preencha nome,
matrícula e senha.

---

# Iniciar o sistema

Na pasta `PROJETOBUS\backend`:

```
npm run dev
```

Deixe esse terminal aberto. Quando aparecer `PROJETOBUS Backend rodando na porta 3000`, abra no navegador:

**http://localhost:3000**

Se você mudou o `PORT` no `.env`, use essa porta no endereço.

---

# Acessar o painel administrativo

1. Abra **http://localhost:3000**.
2. Entre com o usuário e a senha do administrador.

Abas principais: **Painel** (resumo ao vivo, km e combustível por ônibus), **Verificação**, **Operação**,
**Enviar dados** (relatórios HTML do Smart Report), **Ao vivo** (mapa dos ônibus) e **Frota** (ônibus e
motoristas).

---

# Acessar como motorista

1. Na tela de login, toque em **Sou motorista**.
2. Digite a **matrícula** e a **senha** do motorista.
3. Preencha a **placa do ônibus**, a **linha** e o **km do hodômetro**.
4. Toque em **INICIAR E TRANSMITIR LOCALIZAÇÃO** e permita o acesso à localização.
5. Ao terminar, toque em encerrar e informe o **km do hodômetro no final**.

O ônibus aparece na aba **Ao vivo** do painel. No celular, a localização só funciona por um endereço
**https** (veja a próxima seção).

---

# Acessar pelo celular

O navegador do celular só libera o GPS em endereços **https**. Para isso, com o backend rodando,
abra **outro** PowerShell (o do `npm run dev` precisa continuar aberto) e rode:

```
cloudflared tunnel --url http://localhost:3000
```

1. No terminal aparece um endereço `https://...trycloudflare.com`. Copie esse endereço.
2. Abra o endereço no navegador do celular (Safari no iPhone, Chrome no Android).
3. Toque em **Sou motorista**.
4. Entre com a matrícula e a senha do motorista de teste.

O endereço muda toda vez que o comando é iniciado. Enquanto ele estiver rodando, o sistema fica acessível
pela internet; feche o terminal (ou `Ctrl+C`) quando terminar os testes.

No iPhone, mantenha a tela ligada durante a transmissão: o Safari para o GPS quando a tela apaga.

---

# Credenciais de teste

CREDENCIAIS DE TESTE NÃO ENCONTRADAS NO PROJETO

As contas são criadas no banco de dados e não ficam no repositório. Peça o acesso ao responsável pelo projeto,
ou crie as suas:

## Painel Administrativo

Login:
crie com o comando da seção **Criar o administrador**

Senha:
a que você definir nesse comando

## Motorista

Login:
matrícula cadastrada em **Frota → Motoristas**

Senha:
a definida nesse cadastro

---

# Comandos de teste

Todos na pasta `PROJETOBUS\backend`:

```
npm test
```
Executa os testes automáticos da leitura dos relatórios.

```
npm run importar-dados
```
Importa para o banco os relatórios HTML que estiverem na pasta `PROJETOBUS\dados\` (a pasta não vem no
repositório; crie e coloque os arquivos nela).

```
npm run importar-dados -- --conferir
```
Só lê a pasta `dados\` e mostra as conferências entre os relatórios, sem gravar nada.

```
npm run simular-viagem -- SEMOB "SENHA_DO_ADMIN" 5 02
```
Coloca um ônibus de teste (prefixo 9999) andando no mapa da aba **Ao vivo** por 5 minutos na linha 02.
Use o usuário e a senha do administrador. `Ctrl+C` encerra antes.

---

# PM2

Opcional: o PM2 mantém o sistema rodando em segundo plano, sem precisar deixar terminais abertos.
Instalação (uma vez só):

```
npm install -g pm2
```

Iniciar, a partir da pasta `PROJETOBUS`:

```
pm2 start backend/src/servidor.js --name projetobus-backend --cwd backend
pm2 start "C:/Program Files (x86)/cloudflared/cloudflared.exe" --name projetobus-tunel --interpreter none -- tunnel --no-autoupdate --url http://localhost:3000
```

O segundo comando usa o caminho onde o instalador do Windows coloca o `cloudflared`; ajuste se ele estiver em
outra pasta.

Comandos do dia a dia:

```
pm2 list
pm2 restart projetobus-backend
pm2 restart projetobus-tunel
pm2 logs projetobus-tunel --lines 50
pm2 logs projetobus-backend
```

- `pm2 restart projetobus-backend`: reinicia o sistema (depois de mudar o `.env` ou atualizar o projeto).
- `pm2 restart projetobus-tunel`: gera um novo endereço https para o celular.
- `pm2 logs projetobus-tunel --lines 50`: mostra o endereço https atual (linha com `trycloudflare.com`).

---

# Acesso rápido

1. Baixar o projeto: `git clone https://github.com/Voidrotth/PROJETOBUS.git`
2. Instalar as dependências:
   `cd PROJETOBUS\backend` → `copy .env.example .env` → `npm install` →
   `cd ..\frontend` → `flutter pub get` → `flutter build web`
3. Configurar `PROJETOBUS\backend\.env` (`MONGODB_URI` e `JWT_SEGREDO`).
4. Iniciar o backend: `cd ..\backend` → `npm run dev`
5. Abrir **http://localhost:3000**.
6. Para o celular, abrir outro PowerShell.
7. Iniciar o Cloudflare Tunnel: `cloudflared tunnel --url http://localhost:3000`
8. Abrir no celular o link `https://...trycloudflare.com` que aparecer.
9. Entrar com o administrador para testar o painel.
10. Tocar em **Sou motorista** e entrar com a matrícula e a senha do motorista para testar o motorista.
