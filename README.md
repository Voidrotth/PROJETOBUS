# PROJETOBUS

Sistema de operação de ônibus: o motorista usa o app no celular (inicia a viagem, o GPS é enviado
e, no fim do dia, lança o fechamento com os pagamentos) e a empresa acompanha tudo no painel,
com os ônibus ao vivo no mapa.

## Arquitetura

```
Flutter (painel web + app do motorista)
   │  HTTP (JWT) + Socket.IO
   ▼
Node.js (backend/)  ──── login, regras de negócio, viagens, GPS, pagamentos, API do painel,
   │                         leitura dos relatórios enviados (HTML do Smart Report e CSV)
   │
   ├── MongoDB ────────── banco principal (fonte da verdade)
   │
   ├── OpenRouter (IA) ── só quando um relatório chega com colunas que o sistema não conhece
   │
   └── backend/src/fleetbase/  ── única camada que conversa com o Fleetbase
          │  API /v1 (chave de API)
          ▼
       Fleetbase enxuto (fleetbase/) ── opcional: gestão de frota e mapa no console dele
```

- Relatórios: ARQUIVO → upload → identificar o tipo (pelas colunas; se não bater, a IA sugere o mapa
  de colunas) → extrair → normalizar → validar → banco → painel. A resposta da IA nunca vai direto para o
  banco: o mapa é conferido contra o catálogo e contra os dados antes. Detalhes em
  [docs/ANALISE_DADOS.md](docs/ANALISE_DADOS.md).
- Não há entrada por e-mail: os dados chegam só pelo upload no painel (ou pela pasta `dados/`).
- O Flutter só conhece a API do Node. Não sabe que o Fleetbase existe.
- O Node salva tudo no MongoDB e manda ao Fleetbase só o que interessa a ele: veículos,
  motoristas, quem está rodando e a posição mais recente.
- Se o Fleetbase estiver desligado ou fora do ar, o sistema funciona igual. O que não foi
  enviado fica marcado como pendente e é reenviado sozinho a cada minuto.
- O tempo real do painel é Socket.IO no próprio Node. O Fleetbase tem o dele (SocketCluster),
  mas usar os dois criaria uma segunda arquitetura só para isso.

O Fleetbase em si não faz parte deste repositório (ver item 5 de "Como rodar").

## Como rodar

### 1. Backend

```bash
cd backend
cp .env.example .env      # preencha MONGODB_URI, JWT_SEGREDO e OPENROUTER_API_KEY
npm install
npm run criar-usuario -- admin@semob.com "SUA_SENHA" "Administrador" admin
npm run dev
```

Teste: `curl http://localhost:3000/api/saude`

### 2. Painel (Flutter web)

```bash
cd frontend
flutter pub get
flutter run -d chrome      # ou -d edge
```

Se o backend não estiver na porta 3000 (variável `PORT` do `.env`), informe o endereço:
`flutter run -d chrome --dart-define=API_URL=http://localhost:3100/api`.

Entre com o admin criado acima. Em **Frota**, cadastre os veículos e os motoristas (o e-mail e a
senha do motorista são o login dele no app).

### 3. App do motorista (celular Android)

O celular precisa acessar o computador pela rede: use o IP do computador, não `localhost`.

```bash
cd frontend
flutter run -d <celular> --dart-define=API_URL=http://192.168.0.10:3000/api
```

As pastas `android/` e `ios/` já vêm com as permissões de localização em segundo plano.

### 4. Verificação do relatório mensal

O gestor manda os relatórios do verificador pela aba **Enviar dados** (HTML do Smart Report e
planilhas CSV) e confere tudo nas abas **Verificação** (demanda, receita, crédito circulante com
alerta, quilometragem e exportações) e **Operação** (cumprimento por turno, linhas, horários,
frota, viagens não cumpridas e pesquisa de viagens).

A pasta `dados/` (relatórios reais) não vai para o repositório. Quem tiver os arquivos pode
colocá-los em `dados/` na raiz do projeto (qualquer subpasta) e importar sem passar pela tela:

```bash
cd backend
npm run importar-dados                 # lê, confere e grava
npm run importar-dados -- --conferir   # só lê e mostra as conferências (não grava)
npm test                               # leitura dos relatórios e validação da resposta da IA
```

Planilha CSV (para o que o Smart Report não traz, como a receita de catraca): primeira coluna
`data`, as outras com o nome do campo. Exemplo: `data;receitaCatracaDinheiro;receitaCatracaCartao`.

Estrutura dos relatórios, campos, regras de identificação e validação: [docs/ANALISE_DADOS.md](docs/ANALISE_DADOS.md).
O que os dados permitem (e o que não permitem): [docs/RELATORIO_TECNICO.md](docs/RELATORIO_TECNICO.md).

### 5. Fleetbase (opcional)

O sistema funciona sem o Fleetbase: com `FLEETBASE_API_KEY` vazio no `backend/.env` a integração
fica desligada e a frota usa só o MongoDB. Para ligar, suba um Fleetbase
(https://github.com/fleetbase/fleetbase, testado com a v0.7.63), crie uma chave em
**Developers > API Keys** no console e preencha `FLEETBASE_URL` e `FLEETBASE_API_KEY` no `backend/.env`.

## Fluxo do motorista

1. **Login**: e-mail e senha.
2. **Seleciona o veículo** (ônibus já em viagem aparecem bloqueados), informa a linha e o km inicial.
3. **Iniciar viagem**: o GPS liga. No Android aparece uma notificação fixa, e com ela o GPS continua
   com a tela bloqueada.
4. As posições vão para uma **fila salva no celular** e são enviadas em lotes a cada 30 s. Sem
   internet, a fila guarda tudo e envia quando a conexão voltar. Se o app fechar, a fila e a
   viagem são retomadas ao abrir de novo.
5. **Encerrar viagem**: km final, passageiros, voltas, dinheiro, cartão, Pix, gratuidades e
   ocorrências. O fechamento vira uma **Operação** (a mesma do painel, junto com as do cadastro manual) e um **Pagamento**, e aparece no painel na hora.

## API do backend (novas rotas)

Todas pedem `Authorization: Bearer <token>`, exceto o login.

| Rota | Quem | O quê |
|---|---|---|
| `POST /api/auth/login` | todos | `{email, senha}` → `{token, usuario}` |
| `GET /api/auth/eu` | todos | usuário logado |
| `GET/POST/PUT /api/usuarios` | admin | motoristas e administradores |
| `GET /api/veiculos` | todos | lista (com `emUso`) |
| `POST/PUT /api/veiculos` | admin | cadastro de veículos |
| `POST /api/viagens/iniciar` | motorista | `{veiculoId, linha, kmInicial?}` |
| `GET /api/viagens/atual` | motorista | viagem aberta (para retomar) |
| `POST /api/localizacao` | motorista | `{viagemId, posicoes: [{latitude, longitude, velocidade, direcao, precisao, horario}]}` |
| `POST /api/viagens/:id/encerrar` | motorista | `{kmFinal, passageiros, voltas, ocorrencias, pagamento: {dinheiro, cartao, pix, gratuidades}}` |
| `GET /api/viagens/ao-vivo` | admin | ônibus rodando + última posição |
| `GET /api/viagens?status=&data=` | admin | histórico com pagamentos |
| `GET /api/viagens/:id/trajeto` | admin/dono | pontos do GPS |
| `GET /api/fleetbase/status` | admin | integração ligada/conectada |
| `GET /api/indicadores?inicio=&fim=&tipos=` | admin | indicadores diários, resumo por mês, alerta e conferências (`tipos`: util, nao_util, feriado) |
| `POST /api/indicadores/arquivos?envio=&nome=` | admin | recebe um arquivo `.html` ou `.csv` (corpo = o arquivo) |
| `POST /api/indicadores/processar` | admin | relê tudo que foi enviado, confere e atualiza o banco |
| `GET /api/indicadores/operacao?inicio=&fim=&tipos=&linha=` | admin | resumo, turnos, por linha, por hora, linha × hora, frota e viagens não cumpridas |
| `GET /api/indicadores/viagens?...&prefixo=&sentido=&hora=&pagina=` | admin | pesquisa de viagens (200 por página) |
| `PUT/DELETE /api/indicadores/feriados/:data` | admin | cadastro de feriados |
| `GET /api/indicadores/exportar?formato=csv\|xlsx&escopo=tudo\|quilometragem` | admin | exportação com os mesmos filtros |
| `GET /api/indicadores/relatorio-quilometragem` | admin | página para imprimir ou salvar em PDF |

Socket.IO (só admin, token em `auth.token`): `viagem:iniciada`, `viagem:posicao`, `viagem:encerrada`.

As rotas `/api/painel` e `/api/operacoes` continuam como estavam; `/api/importacoes` e `/api/email`
(entrada por e-mail) foram removidas. O `/api/painel/resumo` agora também traz `arrecadacao` e `viagensEmAndamento`.

## Banco (MongoDB)

| Coleção | Conteúdo |
|---|---|
| `usuarios` | admins e motoristas (`fleetbaseId` = motorista no Fleetbase) |
| `veiculos` | frota (`fleetbaseId` = veículo no Fleetbase) |
| `viagens` | cada jornada: início, fim, km informado, km pelo GPS, última posição |
| `localizacoes` | todos os pontos de GPS (sem duplicar reenvios da fila) |
| `pagamentos` | fechamento financeiro de cada viagem |
| `operacoes` | operações do app do motorista e do cadastro manual |
| `indicadordiarios` | um registro por data com os indicadores dos arquivos enviados (`linha` nulo = total do sistema) |
| `viagensrealizadas` | cada viagem do relatório "Viagens" (e a km improdutiva de cada veículo por dia) |
| `viagensnaocumpridas` | viagens não realizadas, não iniciadas e não terminadas |
| `importacaodados` | arquivos lidos (tipo reconhecido pela assinatura ou pela IA) e conferências de cada leitura |
| `mapeamentoias` | mapas de colunas sugeridos pela IA e já validados (o mesmo layout não volta para a IA) |
| `feriados` | feriados cadastrados pelo gestor |
