# Análise da pasta `dados/` — referência oficial para a IA, o banco e o painel

Análise feita em 03/10/2026 lendo **todos** os 44 arquivos de `dados/` (nenhum foi alterado).
Os números deste documento saem de scripts que leem os HTML e cruzam os relatórios entre si; nada foi
digitado à mão nem presumido. Onde um significado não pode ser confirmado pelos arquivos, está escrito.

Complementa o `RELATORIO_TECNICO.md` (indicadores, lacunas e inconsistências de jul–set/2026).

---

## 1. As pastas

`dados/` tem 3 pastas, uma por mês. Dentro de cada mês, uma subpasta por **emissão** (periodicidade):

| Pasta | Subpastas | Arquivos | Gerado em | Cobre |
|---|---|---|---|---|
| `Julho_2026` | `Mensal` | 11 | 04/08/2026 14:37 | operação 01–31/07; bilhetagem 01/07–03/08 |
| `Agosto_2026` | `Quinzenal`, `Mensal` | 11 + 11 | 15/08/2026 07:17 e 04/09/2026 08:00 | 01–14/08 e 01–31/08 (créditos até 01/09) |
| `Setembro_2026` | `Quinzenal`, `Mensal` (**vazia**) | 11 + 0 | 15/09/2026 08:00 | 01–14/09 |

**Função das pastas:** são o mesmo pacote de relatórios emitido em datas diferentes. O nome da pasta é só
organização; o tipo de cada arquivo e o período que ele cobre saem **do conteúdo** (título, colunas, datas
das linhas). O Quinzenal de agosto é um subconjunto exato do Mensal de agosto (16.819 de 16.819 viagens
idênticas), ou seja, a emissão mais nova **substitui** a mais velha nos dias em comum.

Todos os 44 arquivos são `.html` (Cp1252), gerados pelo "Smart Report" (SmartDataSource). Não há CSV,
XLSX, PDF, JSON nem TXT.

## 2. Estrutura comum de todos os arquivos

Cada arquivo é a **concatenação de 2 ou 3 documentos HTML** (`<!DOCTYPE …><html>…</html>` repetido):

1. **Cabeçalho de geração**: tabela `SmartDataSource.com | Horário` com 1 linha
   `Gerado por "Smart Report" | <data/hora>`. Dois formatos:
   - relatórios de **operação** (domínio `SmartDataSource.com`): `dd/mm/aaaa hh:mm`;
   - relatórios de **bilhetagem** (domínio `SmartDataSource.com.br`, título com "São Caetano do Sul"):
     `dd-Mmm hh:mm` **sem ano** (`04-Set 08:01`).
2. **Um documento por relatório**: `<title>` = `<h1>` = `"<Periodicidade> - <Relatório>"` (operação) ou
   `"São Caetano do Sul - <Relatório>"` (bilhetagem), seguido de `<table class='data'>` com `<th>` (colunas)
   e `<tr class='even|odd'>` (linhas). `Saldos*` traz **dois** relatórios no mesmo arquivo.
3. Linha de **total** no fim da tabela (ver cada tipo). Ela não é dado: é usada só para validar a soma.

Tabela vazia (só cabeçalho, 0 linhas) é válida e significa "nenhuma ocorrência no período"
(ex.: `Quinzenal_Viag_Ninic_202609` — nenhuma viagem não iniciada em 01–14/09).

## 3. Os 11 tipos de relatório

Os mesmos 11 tipos (12 relatórios, porque `Saldos` tem 2) aparecem em todas as emissões, com
**exatamente as mesmas colunas**. Linhas de dados por emissão:

| Tipo (título) | Arquivo | Jul M | Ago Q | Ago M | Set Q | Grão (1 linha =) |
|---|---|---:|---:|---:|---:|---|
| A. Resumo Geral | `Mensal_AAAAMM`, `Quinzenal_AAAAMM` | 31 | 14 | 31 | 14 | dia |
| B. Fator de Cumprimento de Viagem | `*_FCV_*` | 31 | 14 | 31 | 14 | dia |
| C. Resumo por Linha | `*_Linhas_*` | 293 | 126 | 279 | 126 | dia × linha |
| D. Partidas por Faixa Horária | `*_FxHr_*` | 5.882 | 2.531 | 5.598 | 2.526 | dia × linha × hora |
| E. Resumo por Faixa Horária | `*_Resumo_FxHr_*` | 651 | 294 | 651 | 294 | dia × hora |
| F. Viagens | `*_Viagens_*` (6–14 MB) | 38.077 | 16.819 | 36.751 | 16.280 | viagem (ou veículo × dia, se improdutiva) |
| G. Viagens não Realizadas | `*_Viag_NRealiz_*` | 50 | 25 | 42 | 8 | viagem programada |
| H. Viagens não Iniciadas | `*_Viag_Ninic_*` | 3 | 6 | 6 | 0 | viagem programada |
| I. Viagens não Terminadas | `*_Viag_NTerm_*` | 4 | 8 | 8 | 1 | viagem programada |
| J. Passageiros do Sistema | `Passageiros*` | 20 | 13 | 31 | 14 | dia |
| K. Saldo de créditos do sistema | `Saldos*` (1ª tabela) | 16 | 10 | 25 | 14 | dia com transferência |
| L. Venda x Utilização | `Saldos*` (2ª tabela) | 29 | 14 | 32 | 14 | dia |

A–I são **operação** (GPS/frota); J–L são **bilhetagem** (cartões e créditos).

### A. Resumo Geral — operação do dia

| Coluna | Tipo / formato | Exemplo | Campo canônico |
|---|---|---|---|
| `Data` | `dd/mm/aaaa` | `01/08/2026` | `data` (AAAA-MM-DD) — **chave** |
| `diaSem` | `Seg Ter Qua Qui Sex Sab Dom` | `Sab` | `diaSemana` (confere com o calendário) |
| `nrVeiculos` | inteiro | `37` | `veiculos` = prefixos distintos com viagem normal no dia |
| `nrMaxVeicFx` | inteiro | `35` | `maxVeiculosFaixa` = maior `Nr_Veiculos` do relatório E no dia |
| `nrViagensProgr` | inteiro | `924` | `viagensProgramadas` (**só existe aqui e no FCV**) |
| `nrViagensRealiz` | inteiro | `924` | `viagensRealizadas` |
| `Dif Viagens` | inteiro | `0` | `viagensNaoCumpridas` = Progr − Realiz |
| `kmProd` | decimal vírgula, sem milhar | `6889,4` | `kmProdutiva` |
| `kmImprod` | idem | `344,3` | `kmImprodutiva` |
| `kmTotal` | idem | `7233,7` | `kmTotal` = kmProd + kmImprod |

Total: linha `Total Geral` (Data = "Total Geral", diaSem e veículos vazios).

### B. Fator de Cumprimento de Viagem — viagens por turno

`Data`, `manha_p`, `manha_r`, `tarde_p`, `tarde_r`, `noite_p`, `noite_r`, `programadas`, `realizadas`
(todos inteiros). `_p` = programadas, `_r` = realizadas. `programadas`/`realizadas` = Resumo Geral do dia;
manhã + tarde + noite = total. É a **única fonte das programadas por turno**. Os limites de horário de
cada turno **não estão nos arquivos**. Total: última linha com `Data` vazia.

### C. Resumo por Linha

`Data`, `Linha` (`01`…`08`, `10`, `11`; texto com zero à esquerda), `kmTotal`, `nrViagens`.
Atenção: **`kmTotal` aqui é a km produtiva** (Σ `kmProd` das viagens da linha; 100% dos 824 registros),
não a km total. `nrViagens` = viagens normais da linha no dia. Total: última linha com `Data` vazia.

### D. Partidas por Faixa Horária

`Data`, `Linha`, `Fx_Hor` (`0hs`…`23hs`; não há 1hs–3hs), `Nr_Veiculos`, `Nr_Viagens`, `Partidas`.
`Partidas` = lista dos **minutos** de saída dentro da hora, separados por `>` (`34 > 57 > 59`); a quantidade
de minutos = `Nr_Viagens` e os minutos = minuto do `inicioRealizado` das viagens (100%). Total: última
linha só com `Nr_Viagens`.

### E. Resumo por Faixa Horária

`Data`, `Fx_Hor`, `Nr_Veiculos`, `Nr_Viagens`. `Nr_Viagens` = Σ do relatório D; `Nr_Veiculos` = prefixos
distintos com viagem **normal** iniciada na hora (100%). Total: última linha só com `Nr_Viagens`.

### F. Viagens — o dado mais detalhado

| Coluna | Formato | Obrigatório | Campo canônico |
|---|---|---|---|
| `Data` | `dd/mm/aaaa` | sim | `data` (**dia operacional**: 177 viagens de agosto começam depois da meia-noite e ficam no dia anterior) |
| `Linha` | `01`…`11` | só em viagem normal | `linha` |
| `Prefixo` | inteiro (nº do ônibus) | sim | `prefixo` (57 veículos; 55 rodam em mais de uma linha) |
| `Atividade` | `Viagem Normal` \| `Improdutivas` | sim | `atividade`: `normal` \| `improdutiva` |
| `Sentido` | `I` \| `V` | só em viagem normal | `sentido`: `ida` \| `volta` |
| `Fx_Hor` | inteiro 0–23 | sim | `hora` (= hora do `inicioRealizado`; `0` nas improdutivas) |
| `inicioRealizado` | `aaaa-mm-dd hh:mm:ss` | só em viagem normal | `inicio` |
| `fimRealizado` | idem | só em viagem normal | `fim` (duração 7 a 74 min; nunca negativa) |
| `kmProd` | decimal vírgula | sim | `kmProdutiva` (0 nas improdutivas) |
| `kmImprod` | idem | sim | `kmImprodutiva` (0 nas normais) |
| `kmTotal` | idem | sim | `kmTotal` = kmProd + kmImprod (100%) |

`Improdutivas` **não é uma viagem**: é 1 linha por veículo por dia com a km improdutiva total
(deslocamento garagem/linha), sem linha, sentido nem horário. Total: última linha com `Data` vazia.

### G, H, I. Viagens não Realizadas / não Iniciadas / não Terminadas

Mesmas 15 colunas nos três:

| Coluna | G. não realizada | H. não iniciada | I. não terminada | Campo canônico |
|---|---|---|---|---|
| `Data`, `Linha` | sim | sim | sim | `data`, `linha` |
| `Atendimento` | sim | sim | sim | `atendimento` (nome do itinerário + sentido) |
| `Prefixo` | **vazio** | sim | sim | `prefixo` |
| `Atividade` | `Viagem Normal` | idem | idem | (ignorado: sempre normal) |
| `Motorista` | sim | sim | sim | `motorista` (matrícula numérica; 47 distintos) |
| `Sentido` | `I`/`V` | idem | idem | `sentido` |
| `Tabela` | sim | sim | sim | `tabela` (escala do veículo: `1A`, `3B`…) |
| `statusSaida` | vazio | vazio | `RG` `AD` `AT` | `statusSaida` |
| `statusChegada` | vazio | `RG` `AD` | vazio | `statusChegada` |
| `inicioProgramado`, `fimProgramado` | sim | sim | sim | `inicioProgramado`, `fimProgramado` |
| `inicioRealizado` | vazio | vazio | sim | `inicioRealizado` |
| `fimRealizado` | vazio | sim | vazio | `fimRealizado` |
| `kmProd` | `0` | `0` | `0` | (ignorado: sempre 0) |

G + H + I do dia = `Dif Viagens` do Resumo Geral (100% dos dias). Os códigos `RG`, `AD`, `AT` **não
são explicados** nos arquivos: são guardados como vieram. Sem linha de total.

### J. Passageiros do Sistema

`Mês` (`aaaa-mm`), `Dia` (`01`…`31`), `Catraca`, `Antecipados`, `Não Pagantes`, `Total Passageiros`.
Inteiros **com ponto de milhar** (`10.700`). Catraca + Antecipados + Não Pagantes = Total. Texto fixo:
"a quantidade de passageiros é provisória" (pode mudar em emissões futuras). Total: `Dia` = `Total Mês`,
uma por mês (o arquivo pode cobrir 2 meses).

### K. Saldo de créditos do sistema

`Mês`, `Dia`, `Série` (sempre `1`), `Créditos transferidos para cartões`, `Saldo Final`. Reais com milhar
e vírgula (`20.434.667,35`). Só aparecem dias com transferência (exceto setembro, que lista zeros).
Saldo anterior − transferido = saldo final (exceções no `RELATORIO_TECNICO.md`, item 8).
`Créditos transferidos` pode vir **vazio** num dia listado (02/08 no quinzenal de agosto): é opcional e
fica nulo, nunca zero.

### L. Venda x Utilização

`Mês`, `Dia`, `Total Vendas`, `Total Utilização`, `Crédito Circulante` (R$, pode ser negativo).
Vendas − Utilização = Circulante. Nota fixa do relatório: venda e uso do crédito não acontecem no mesmo dia.

## 4. Relacionamentos

```
                         data (dia operacional) liga tudo
 ┌──────────────────────────────┬───────────────────────────────────────────┐
 │ OPERAÇÃO                     │ BILHETAGEM                                │
 │ A Resumo Geral (dia) ◄─ soma ─ F Viagens (viagem)                        │ J Passageiros (dia)
 │ B FCV (dia × turno)          │   ├─ por linha  → C Resumo por Linha      │ K Saldo de créditos (dia)
 │ G+H+I não cumpridas ── Σ ──► A.Dif Viagens                               │ L Venda x Utilização (dia)
 │                              │   ├─ por hora   → E Resumo por Faixa      │
 │                              │   └─ linha+hora → D Partidas por Faixa    │
 └──────────────────────────────┴───────────────────────────────────────────┘
 Chaves: data · linha (01…11) · prefixo (veículo) · motorista · hora (0–23)
```

Conferido em todas as emissões (0 divergências):

- F (normais) por dia = A.`nrViagensRealiz`; Σ km de F = A.`kmProd`/`kmImprod`.
- F por dia × linha = C (`nrViagens` e `kmTotal`=Σ kmProd).
- F por dia × linha × hora = D (`Nr_Viagens` e minutos de `Partidas`); Σ D = E; prefixos distintos = E.`Nr_Veiculos`.
- prefixos distintos de F (normais) no dia = A.`nrVeiculos`; máximo de E no dia = A.`nrMaxVeicFx`.
- B.`programadas`/`realizadas` = A; G + H + I = A.`Dif Viagens`.
- **Consequência:** C, D e E são inteiramente deriváveis de F. O que **só** existe em resumo:
  viagens programadas (A, B), programadas por turno (B), viagens não cumpridas com motorista e tabela (G, H, I).

Linha × atendimento (G, H, I): cada linha tem 2 a 4 nomes de atendimento, escritos de formas diferentes
para o mesmo itinerário (`B. BOA VISTA` / `BAIRRO BOA VISTA`, `ESTACAO` / `ESTAÇÃO`, `CIRC.` / `CIRCULAR`).

## 5. O que a IA precisa identificar em um arquivo novo

Para cada documento do HTML:

1. **Tipo de relatório** (A a L), pelo título + colunas, nunca pelo nome do arquivo.
2. **Data/hora de geração** (cabeçalho), com o ano deduzido do `Mês` quando o formato é `dd-Mmm`.
3. **Periodicidade** (`Mensal`/`Quinzenal`, do título; bilhetagem não informa).
4. **Mapa coluna → campo canônico** (seção 3).
5. **Linhas de total** a separar dos dados.
6. **Período coberto** (primeira e última data das linhas de dados).

Ignorar: o documento "Utilize [Ctrl +]…", rodapé `[ SmartDataSource.com ]`, a tabela `info` vazia, o CSS,
`Série` (constante), `Atividade` e `kmProd` em G/H/I (constantes).

## 6. Regras de identificação

| Tipo | Assinatura (colunas normalizadas: sem acento, minúsculas, sem espaço/_) | Título contém |
|---|---|---|
| A | data, diasem, nrveiculos, nrviagensprogr, nrviagensrealiz, kmprod, kmimprod, kmtotal | Resumo Geral |
| B | data, manhap, manhar, tardep, tarder, noitep, noiter, programadas, realizadas | Cumprimento |
| C | data, linha, kmtotal, nrviagens | Resumo por Linha |
| D | data, linha, fxhor, nrveiculos, nrviagens, partidas | Partidas por Faixa |
| E | data, fxhor, nrveiculos, nrviagens | Resumo por Faixa |
| F | data, linha, prefixo, atividade, sentido, fxhor, iniciorealizado, fimrealizado, kmprod, kmimprod, kmtotal | Viagens |
| G/H/I | data, linha, atendimento, prefixo, motorista, sentido, tabela, statussaida, statuschegada, inicioprogramado, … | não Realizadas / não Iniciadas / não Terminadas |
| J | mes, dia, catraca, antecipados, naopagantes, totalpassageiros | Passageiros |
| K | mes, dia, serie, creditostransferidosparacartoes, saldofinal | Saldo de créditos |
| L | mes, dia, totalvendas, totalutilizacao, creditocirculante | Venda x Utilização |

1. **Reconhecimento direto**: as colunas batem com uma assinatura (todas as obrigatórias presentes) → tipo
   identificado sem IA. G, H e I têm as mesmas colunas: o título decide.
2. **IA (só quando o passo 1 falha)**: colunas renomeadas, reordenadas, a mais ou a menos. A IA recebe o
   título, as colunas e até 5 linhas de amostra **(nunca o arquivo inteiro: Viagens tem 14 MB)** e o
   catálogo da seção 3, e devolve `{tipo, mapa coluna→campo, confiança}`. A extração das linhas é feita
   pelo código com esse mapa, não pela IA.
3. A resposta da IA é validada: tipo existente, toda coluna mapeada existe no arquivo, todo campo
   obrigatório do tipo foi mapeado e a amostra convertida passa nos tipos. Se não passar → arquivo
   **recusado com o motivo**; nunca adivinhado.

## 7. Normalização e conversão

| Dado | Origem | Normalizado |
|---|---|---|
| Data | `dd/mm/aaaa`, ou `Mês`=`aaaa-mm` + `Dia` | `AAAA-MM-DD` |
| Data/hora | `aaaa-mm-dd hh:mm:ss` | ISO local (America/Sao_Paulo) |
| Gerado em | `dd/mm/aaaa hh:mm` ou `dd-Mmm hh:mm` | data/hora; ano do `dd-Mmm` = ano do último `Mês`, +1 se o mês de geração for anterior |
| Número | `8543,6` / `10.700` / `20.434.667,35` | ponto = milhar, vírgula = decimal (nenhum arquivo usa ponto decimal) |
| Linha | `01` | texto com 2 dígitos |
| Faixa | `4hs` / `4` | inteiro 0–23 |
| Atividade | `Viagem Normal` / `Improdutivas` | `normal` / `improdutiva` |
| Sentido | `I` / `V` | `ida` / `volta` |
| Atendimento | `B. BOA VISTA SENTIDO ESTACAO` | guardado como veio + forma sem acento e com abreviações expandidas para agrupar |
| Partidas | `34 > 57 > 59` | não guardado (é derivável das viagens) |
| Vazio | `''` | `null` (nunca 0) |

## 8. Regras de validação (antes de gravar)

Por linha:
- campos obrigatórios presentes; números válidos e ≥ 0 (exceto `Crédito Circulante`);
- data válida; `diaSem` = dia da semana da data; `inicio` < `fim`;
- viagem normal tem linha, sentido, início e fim; improdutiva tem kmProd = 0;
- G sem prefixo/horário realizado; H sem `inicioRealizado`; I sem `fimRealizado`.

Por relatório:
- soma das linhas = linha de total (A, B, C, D, E, F, J, K, L);
- kmProd + kmImprod = kmTotal; Progr − Realiz = Dif; Catraca + Antecipados + Não Pagantes = Total;
  Vendas − Utilização = Circulante; manhã + tarde + noite = total;
- sem chave duplicada no mesmo relatório.

Entre relatórios da mesma emissão: as conferências da seção 4. Divergência **não bloqueia** a gravação
(os relatórios são oficiais), mas fica registrada na importação e aparece no painel.

Entre emissões (o mesmo dia em dois arquivos): vale o relatório **gerado por último**; os valores que
mudaram ficam registrados como revisão. Arquivo idêntico (mesmo hash) é ignorado.

Bloqueia a gravação do relatório: tipo não reconhecido, campo obrigatório ausente, valor que não converte,
data inválida, chave duplicada.

## 9. Modelo único de dados

O mesmo vocabulário (campos canônicos da seção 3) é usado pela IA (mapa de colunas), pelo validador,
pelo banco e pelo painel.

O catálogo em código é `backend/src/servicos/modelosRelatorios.js` (coluna, tipo, obrigatório e descrição
de cada campo de cada relatório).

| Coleção | Chave única | Vem de | Campos |
|---|---|---|---|
| `indicadordiarios` | `data` (+ `linha` nulo) | A, B, J, K, L (+ CSV) | diaSemana, programacaoReduzida, veiculos, maxVeiculosFaixa, viagensProgramadas, viagensRealizadas, viagensNaoCumpridas, kmProdutiva, kmImprodutiva, kmTotal, manhaProgramadas, manhaRealizadas, tardeProgramadas, tardeRealizadas, noiteProgramadas, noiteRealizadas, catraca, antecipados, naoPagantes, passageiros, vendas, utilizacao, circulante, transferidos, saldoFinal, receitaCatracaDinheiro, receitaCatracaCartao, fontes, revisoes |
| `viagensrealizadas` | `data + prefixo + atividade + inicio` | F | data, linha, prefixo, atividade, sentido, hora, inicio, fim, kmProdutiva, kmImprodutiva, kmTotal, fonte |
| `viagensnaocumpridas` | `data + linha + tabela + inicioProgramado` | G, H, I | tipo (`nao_realizada`/`nao_iniciada`/`nao_terminada`), data, linha, atendimento, itinerario (normalizado), prefixo, motorista, sentido, tabela, statusSaida, statusChegada, inicioProgramado, fimProgramado, inicioRealizado, fimRealizado, fonte |
| `importacaodados` | — | todos | por arquivo: relatórios, registros, gerado em, período, uso, identificacao (assinatura/ia/planilha), erro; conferências com divergências |
| `mapeamentoias` | título + colunas | IA | tipo e mapa campo → coluna que a IA sugeriu **e que passou na validação**; o mesmo layout não volta para a IA |

`viagensrealizadas` não se chama `viagens` porque essa coleção já existe (viagens abertas pelo motorista no app).

C, D e E **não viram coleção**: são conferidos contra F e o painel calcula por linha, hora e veículo a partir
de `viagens`. Gravação de `viagens` e `viagensnaocumpridas` por dia: a emissão mais nova de um dia
substitui o conjunto inteiro daquele dia (assim viagens removidas numa revisão também saem).

Volume: ~108 mil viagens em 2,5 meses (~45 mil/mês).

## 10. Fluxo

```
ARQUIVO HTML ─► upload ─► separar documentos e tabelas ─► identificar tipo
   (assinatura; se falhar, IA com título + colunas + amostra) ─► extrair com o mapa ─► normalizar
   ─► validar (linha, relatório, entre relatórios, entre emissões) ─► gravar ─► painel
```

Sem e-mail em nenhuma etapa: entrada só por upload no painel (ou pela pasta `dados/` via script).

| Etapa | Onde |
|---|---|
| Upload | `POST /api/indicadores/arquivos` (guarda em `dados/enviados/<envio>/`) |
| Ler HTML, identificar, extrair, normalizar, validar linha a linha | `backend/src/servicos/leitorRelatorios.js` |
| IA (só para layout desconhecido) | `backend/src/servicos/servicoIA.js` (OpenRouter, `IA_MODELO` no `.env`) |
| Consolidar emissões, conferir relatórios entre si, gravar | `backend/src/servicos/servicoIngestao.js` |
| Rodar sem a tela | `npm run importar-dados` (ou `-- --conferir` para só conferir) |
| Teste | `npm test` (reconhecimento dos 44 arquivos e recusa de respostas erradas da IA) |

Testado com os 44 arquivos: todos reconhecidos pela assinatura (sem IA), 91.108 viagens e 122 não
cumpridas gravadas, todas as conferências da seção 4 sem divergência. Testado também com um Resumo Geral
de colunas renomeadas: a IA mapeou os 10 campos e os dados passaram na validação.

## 11. O que o painel usa

Tudo filtrável por **período**, **tipo de dia** (útil / sábado / domingo / feriado) e, onde existe, **linha**.

| Componente | Dados | Fonte |
|---|---|---|
| Cards de operação | viagens programadas, realizadas, % cumprimento, não cumpridas, km produtiva/improdutiva/total, % km improdutiva, frota média e máxima | indicadordiarios |
| Cards de bilhetagem | passageiros total, pagantes (catraca + antecipados), gratuitos, vendas, utilização, circulante, saldo de créditos | indicadordiarios |
| Gráfico diário | viagens programadas × realizadas; km produtiva + improdutiva; passageiros (catraca, antecipados, não pagantes) | indicadordiarios |
| Cumprimento por turno | programadas × realizadas manhã/tarde/noite | indicadordiarios.turnos |
| Por linha | viagens, km produtiva, participação %, não cumpridas por linha | viagens, viagensnaocumpridas |
| Por hora | viagens e veículos por hora (mapa de calor dia × hora ou linha × hora) | viagens |
| Frota | veículos por dia, km por veículo, linhas atendidas por veículo, km improdutiva por veículo | viagens |
| Não cumpridas | tabela com tipo, data, linha, atendimento, motorista, tabela, horários; agrupado por linha, motorista e tipo | viagensnaocumpridas |
| Pesquisa de viagens | por data, linha, prefixo, sentido, hora | viagens |
| Créditos | vendas × utilização, circulante acumulado, saldo final, transferidos | indicadordiarios |
| Importações | arquivos recebidos, tipo identificado (assinatura ou IA), período, divergências, revisões | importacaodados |

O painel **não** mostra o que os arquivos não têm: receita de catraca em R$, km programada, tarifa,
limites dos turnos, significado de `RG`/`AD`/`AT`, nome do motorista.
