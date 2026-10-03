# Relatório técnico — dados reais de jul–set/2026 e painel de verificação

Análise feita em 02/10/2026 sobre a pasta `dados/`. Nenhum arquivo original foi alterado.
Todos os números abaixo saem da leitura automática da pasta (`cd backend && npm run importar-dados -- --conferir`),
que lê a pasta e refaz as conferências; nada foi digitado à mão.

## 1. Arquivos analisados

44 arquivos HTML gerados pelo "Smart Report" (SmartDataSource), codificação Cp1252, São Caetano do Sul.
Cada arquivo contém vários documentos `<html>` colados (um com o horário de geração, depois as tabelas).
Os relatórios foram identificados pelo **título e pelas colunas da tabela**, não pelo nome do arquivo.

| Emissão (pasta) | Gerado em | Cobre |
|---|---|---|
| `Julho_2026/Mensal` (11 arquivos) | 04/08/2026 14:37 | operação 01–31/07; bilhetagem 15/07–03/08 |
| `Agosto_2026/Quinzenal` (11) | 15/08/2026 07:17 | operação 01–14/08; passageiros 01–13/08 |
| `Agosto_2026/Mensal` (11) | 04/09/2026 08:00 | operação 01–31/08; créditos até 01/09 |
| `Setembro_2026/Quinzenal` (11) | 15/09/2026 08:00 | 01–14/09 |

Tipos de relatório em cada emissão:

| Relatório (título) | Arquivo | Conteúdo | Uso |
|---|---|---|---|
| Resumo Geral | `Mensal_AAAAMM` / `Quinzenal_AAAAMM` | 1 linha por dia: veículos, viagens programadas/realizadas, kmProd, kmImprod, kmTotal + "Total Geral" | indicadores |
| Passageiros do Sistema | `Passageiros*` | 1 linha por dia: Catraca, Antecipados, Não Pagantes, Total + "Total Mês" | indicadores |
| Saldo de créditos do sistema | `Saldos*` (1ª tabela) | por dia: Série, Créditos transferidos para cartões, Saldo Final | indicadores |
| Venda x Utilização | `Saldos*` (2ª tabela) | por dia: Total Vendas, Total Utilização, Crédito Circulante | indicadores |
| Viagens | `*_Viagens_*` (6–14 MB) | 1 linha por viagem (16 a 38 mil): linha, prefixo, atividade, sentido, horários, km | conferência |
| Resumo por Linha | `*_Linhas_*` | por dia e linha: kmTotal, nrViagens | conferência |
| Fator de Cumprimento de Viagem | `*_FCV_*` | por dia: programadas/realizadas por manhã, tarde, noite | conferência |
| Viagens não Realizadas / não Iniciadas / não Terminadas | `*_Viag_NRealiz/Ninic/NTerm_*` | 1 linha por viagem não cumprida | conferência |
| Partidas / Resumo por Faixa Horária | `*_FxHr_*`, `*_Resumo_FxHr_*` | viagens por faixa horária | não utilizado |

Não há CSV, XLSX, JSON, PDF nem TXT na pasta.

## 2. Período analisado

- Início: **01/07/2026**. Fim: **14/09/2026** (76 dias corridos, sem data faltando na operação).
- Mês 1: julho/2026 (operação 01–31; **passageiros só de 15 a 31**).
- Mês 2: agosto/2026 (completo em tudo).
- Mês 3: setembro/2026 (**só 01–14**; não existe o relatório mensal de setembro na pasta).

Lacunas:

| Dado | Lacuna |
|---|---|
| Passageiros | 01–14/07 (14 dias) sem registro; 15–30/09 sem relatório |
| Venda x Utilização | 03, 04, 05, 11 e 12/07 sem linha; antes de 15/07 a utilização é sempre 0,00 |
| Saldo de créditos | só a partir de 15/07; dias sem transferência não aparecem (exceto no relatório de setembro, que lista zeros) |
| Operação | 15–30/09 sem relatório |

## 3. Estrutura dos dados

- Datas: `dd/mm/aaaa` na operação; colunas `Mês` (`aaaa-mm`) + `Dia` na bilhetagem.
- Números: operação usa vírgula decimal sem separador de milhar (`8543,6`); bilhetagem usa ponto de milhar
  (`24.140`, `9.365,00`). O leitor trata os dois.
- Unidades: km (1 casa decimal), passageiros (inteiros), créditos em R$ (2 casas).
- Horário de geração: `dd/mm/aaaa hh:mm` na operação e `dd-Mmm hh:mm` (sem ano) na bilhetagem.
- A mesma data aparece em mais de uma emissão (14 dias na operação, 13 nos passageiros, 15 em venda x utilização).
- Coluna `Linha` existe em Viagens, Resumo por Linha e Faixa Horária (linhas 01–08, 10 e, só em julho, 11).
  Há potencial para detalhar por linha no futuro; **não implementado agora**.
- Relação entre arquivos: tudo se liga pela data. Dentro da mesma emissão, o Resumo Geral é a soma do
  arquivo de Viagens, do Resumo por Linha e do FCV.

## 4. Indicadores encontrados

| Indicador | Existe | Calculável | Fonte | Observação |
|---|---|---|---|---|
| Demanda total | SIM | SIM | Passageiros do Sistema (`Total Passageiros`) | a partir de 15/07; o relatório avisa que a quantidade é provisória |
| Pagantes | NÃO (direto) | SIM | `Catraca` + `Antecipados` | soma validada: Catraca + Antecipados + Não Pagantes = Total em todos os dias |
| Gratuitos | SIM | SIM | `Não Pagantes` | |
| Receita antecipada | SIM | SIM | Venda x Utilização (`Total Vendas`) | R$ de créditos vendidos por dia |
| Catraca dinheiro (R$) | NÃO | NÃO | — | só existe a quantidade de passageiros "Catraca", sem R$ e sem forma de pagamento |
| Catraca cartão (R$) | NÃO | NÃO | — | idem |
| Crédito vendido | SIM | SIM | `Total Vendas` | |
| Crédito validado | SIM | SIM | `Total Utilização` | = R$ 5,00 × `Antecipados` em 62 de 62 dias |
| Crédito circulante | SIM | SIM | `Crédito Circulante` | = Vendas − Utilização (validado em todos os dias) |
| Km produtiva | SIM | SIM | Resumo Geral (`kmProd`) | |
| Km improdutiva | SIM | SIM | Resumo Geral (`kmImprod`) | |
| Km total | SIM | SIM | Resumo Geral (`kmTotal`) | = kmProd + kmImprod (validado em todos os dias) |
| Km programada | NÃO | NÃO | — | só existe o **número de viagens** programadas, não a km programada |
| Viagens programadas / realizadas | SIM | SIM | Resumo Geral | |
| Dia da semana | SIM | SIM | Resumo Geral (`diaSem`) | confere com o calendário nos 90 registros |
| Feriado | NÃO | NÃO | — | ver item 7 |
| Veículos em operação | SIM | — | `nrVeiculos`, `nrMaxVeicFx` | não se soma entre dias |
| Saldo de créditos do sistema | SIM | — | `Saldo Final` | estoque que só diminui (de R$ 20,95 mi para R$ 19,67 mi) |

## 5. Indicadores calculados

| | Julho | Agosto | Setembro (01–14) |
|---|---|---|---|
| Dias com operação | 31 | 31 | 14 |
| Dias úteis (programação normal) | 19 | 21 | 9 |
| Seg–sex com programação reduzida | 4 | 0 | 1 |
| Sábados / domingos | 4 / 4 | 5 / 5 | 2 / 2 |
| Viagens programadas | 36.387 | 35.050 | 15.498 |
| Viagens realizadas | 36.330 (99,84%) | 34.994 (99,84%) | 15.489 (99,94%) |
| Km produtiva | 248.321,3 | 261.886,8 | 115.795,6 |
| Km improdutiva | 14.425,5 (5,49%) | 13.807,7 (5,01%) | 6.014,5 (4,94%) |
| Km total | 262.746,8 | 275.694,5 | 121.810,1 |
| Dias com passageiros | 17 (15–31) | 31 | 14 |
| Passageiros catraca | 273.564 | 228.430 | 82.806 |
| Passageiros antecipados | 11.031 | 59.948 | 32.721 |
| Não pagantes | 205.058 (41,9%) | 761.870 (72,5%) | 335.674 (74,4%) |
| Total de passageiros | 489.653 | 1.050.248 | 451.201 |
| Total vendas (R$) | 553.425,63 | 668.605,71 | 90.558,34 |
| Total utilização (R$) | 55.155,00 | 299.740,00 | 163.605,00 |
| Crédito circulante (R$) | 498.270,63 | 368.865,71 | −73.046,66 |
| Créditos transferidos (R$) | 523.855,63 | 676.230,71 | 92.948,34 |

Variação da **média por dia com dados** (os totais não são comparáveis: cobertura diferente em cada mês):

| Indicador | Jul → Ago | Ago → Set | Jul → Set |
|---|---|---|---|
| Passageiros/dia | +17,6% | −4,9% | +11,9% |
| Passageiros/dia útil normal | +22,2% | +0,6% | +22,9% |
| Catraca/dia | −54,2% | −19,7% | −63,2% |
| Antecipados/dia | +198,0% | +20,9% | +260,2% |
| Não pagantes/dia | +103,7% | −2,4% | +98,8% |
| Km total/dia | +4,9% | −2,2% | +2,7% |
| Km total/dia útil normal | +4,7% | 0,0% | +4,6% |
| Vendas/dia | +1,3% | −70,0% | −69,6% |
| Utilização/dia | +355,8% | +20,9% | +450,9% |

Mesmo a média por dia mistura dias úteis e fins de semana em proporções diferentes; por isso a tabela
também traz a comparação só entre dias úteis de programação normal.

## 6. Fórmulas utilizadas

- Pagantes = Catraca + Antecipados.
- Total de passageiros = Catraca + Antecipados + Não Pagantes.
- Crédito circulante do dia = Total Vendas − Total Utilização.
- Crédito circulante acumulado = soma do circulante do dia desde o primeiro dia do período escolhido
  (os relatórios não informam saldo inicial de crédito em circulação).
- Km total = Km produtiva + Km improdutiva.
- Cumprimento = viagens realizadas ÷ viagens programadas.
- Média por dia = total ÷ dias que têm o dado. Variação = (média B − média A) ÷ média A.
- Desvio padrão populacional; mediana com média dos dois centrais quando n é par.
- Pico semanal = dia de maior `Total Passageiros` em cada semana segunda–domingo com os 7 dias presentes.
- Tipo de dia: **feriado** se a data foi cadastrada pelo gestor; senão **não útil** se for sábado ou
  domingo; senão **útil**. Os relatórios não trazem feriados, então o cadastro é manual. O painel sugere
  "dias a conferir": segunda a sexta em que `nrViagensProgr` é menor que o valor mais frequente dos dias de
  segunda a sexta nos 7 dias anteriores e 7 posteriores.
- Alerta do crédito circulante: conta as semanas completas (segunda a domingo) seguidas, da mais recente
  do período para trás, em que as vendas de crédito superaram as validações. 2 ou mais = amarelo; 4 ou
  mais = vermelho. A especificação pede o alerta sem fixar limites; estes foram adotados e ficam em
  `SEMANAS_ALERTA_*` no backend.
- Versão de um dia que aparece em duas emissões: vale a emissão gerada por último; a diferença fica
  registrada como "revisão".

## 7. Dados faltantes

- Receita de catraca em R$ e sua divisão dinheiro/cartão.
- Calendário de feriados. Cinco dias de segunda a sexta rodaram com programação de fim de semana:
  09/07 (qui, 842 viagens = domingo), 10/07 (sex, 1.099 = sábado), 27/07 (seg, 1.140), 28/07 (ter, 924 =
  sábado) e 07/09 (seg, 710 = domingo). Os relatórios não dizem o motivo.
- Passageiros de 01 a 14/07 e tudo de 15 a 30/09.
- Km programada (só há viagens programadas).
- Tarifa: não é informada. O valor de R$ 5,00 por passageiro antecipado é deduzido da razão
  Utilização ÷ Antecipados.
- Definição oficial das colunas (ex.: o que entra em "Catraca" e em "Não Pagantes").
- Valor do subsídio e o relatório do verificador em si: não estão na pasta.

## 8. Inconsistências encontradas

Com evidência; nenhuma é classificada como erro ou irregularidade.

| # | O quê | Evidência |
|---|---|---|
| 1 | Utilização revisada entre emissões | 14/08: `Total Utilização` 0,00 no quinzenal (15/08) e 12.505,00 no mensal (04/09); circulante passou de +4.900,00 para −7.605,00. 01/09: 0,00 no mensal de agosto e 14.800,00 no quinzenal de setembro. O último dia de cada emissão sai com utilização ainda não lançada |
| 2 | Passageiros do quinzenal de agosto terminam um dia antes | operação vai até 14/08, passageiros até 13/08 |
| 3 | Saldo de créditos não fecha em 2 dias | 29/07: saldo caiu R$ 130,00 a mais que o transferido; 30/07: R$ 230,00 a mais. Nos outros 49 dias, saldo anterior − transferido = saldo final |
| 4 | Crédito transferido some e volta | 02/08: 4.805,00 (emissão de julho), vazio (quinzenal de agosto), 4.805,00 (mensal de agosto) |
| 5 | Nome de coluna divergente | no "Resumo por Linha" a coluna `kmTotal` soma exatamente o `kmProd` do Resumo Geral (não o kmTotal) nos 90 dias |
| 6 | Vendas ≠ transferidos | `Total Vendas` e `Créditos transferidos para cartões` só coincidem em 6 de 52 dias (o próprio relatório explica que a venda não vira crédito de imediato) |
| 7 | Linhas da tabela de saldo fora de ordem | emissão de julho lista 15, 16, 31, 30, 29, 17… |
| 8 | Utilização zerada antes de 15/07 | de 01 a 14/07 há vendas e `Total Utilização` = 0,00 em todos os dias, sem relatório de passageiros para comparar |
| 9 | Formatos diferentes entre relatórios | datas, números e horário de geração (item 3) |

O que **confere** (0 divergências): kmProd + kmImprod = kmTotal (90/90); programadas − realizadas = Dif
Viagens (90/90); soma dos dias = "Total Geral"/"Total Mês" em todos os arquivos; Catraca + Antecipados +
Não Pagantes = Total (78/78); Vendas − Utilização = Circulante (89/89); viagens uma a uma × Resumo Geral
(90/90 dias, 107.927 registros); Resumo por Linha × Resumo Geral; FCV × Resumo Geral; não realizadas + não
iniciadas + não terminadas = Dif Viagens (57 em julho, 56 em agosto, 9 em setembro).

Não há data duplicada, registro duplicado, valor nulo ou negativo nos campos de operação e passageiros.
Zeros: vendas = 0,00 em todos os sábados e domingos que têm registro e em 07/09.

## 9. Hipóteses confirmadas

**Confirmado**

- Km total = km produtiva + km improdutiva.
- Crédito circulante = vendas − utilização, calculável dia a dia e acumulado.
- O Resumo Geral é reproduzível a partir das viagens individuais (o gestor consegue auditar o total).
- Demanda separável por dia útil, sábado e domingo (médias 41.465 / 17.931 / 8.310 passageiros).
- Pico semanal entre terça e quinta: nas 8 semanas completas o pico caiu em quarta (4), quinta (3) e
  terça (1); nunca em segunda ou sexta.

**Parcialmente confirmado**

- Receita diária: só a parte de créditos (vendas e utilização). A receita de catraca não existe.
- Comparação de 3 meses: só agosto está completo. Julho tem passageiros em 17 dias e setembro tem 14 dias.
- Filtro dia útil/não útil/feriado: útil e não útil saem da data; feriado depende do cadastro do gestor
  (o painel só sugere os dias de programação reduzida).
- Demanda "provisória": o próprio relatório avisa que os passageiros são atualizados diariamente. Nos 13
  dias em que há duas emissões os valores não mudaram, mas isso não garante os demais.

## 10. Hipóteses não confirmadas

**Não confirmado**

- Separação da receita em antecipada, catraca dinheiro e catraca cartão.
- Estabilidade do crédito circulante: o comportamento muda de mês para mês (julho +498 mil, agosto +369
  mil, setembro −73 mil em 14 dias). Em setembro só 1 de 14 dias teve vendas acima da utilização.

**Impossível avaliar**

- Conferência do valor do subsídio (nem o valor nem o relatório do verificador estão na pasta).
- Km realizada × km programada.
- Efeito de feriados.
- Crédito circulante real em estoque (falta o saldo inicial).

## 11. Limitações

- A composição da demanda muda dentro do período: catraca por dia útil cai de 23.819 (15–24/07) para
  9.543 (29/07–31/08) e 7.806 (setembro), enquanto não pagantes sobem de 11.403 para 30.616 e 32.949.
  Os dados não dizem a causa; médias que atravessam 27/07 misturam dois regimes.
- A programação muda em 15/07: dia útil passa de 1.394 para 1.280 viagens e a km produtiva sobe de
  8.527 para 9.510 por dia útil. A data coincide com o início dos dados de passageiros.
- Vendas concentradas: R$ 400.825 entre 24 e 28/08 (60% do mês), R$ 138.950 só em 25/08.
- O acumulado de crédito circulante chega ao máximo de R$ 869.533,17 em 28/08 e recua para
  R$ 794.089,68 em 14/09.
- Tudo depende do layout atual do Smart Report; se as colunas mudarem a importação para com erro em vez de
  adivinhar.

## 12. Decisões técnicas

- **Backend só em Node** (atualizado em 03/10/2026; antes a leitura era um serviço Dart em `ingestao/`):
  leitura, identificação (assinatura das colunas; IA só para layout desconhecido), validação, conferências
  e gravação ficam em `backend/src/servicos/`. Pasta de dados em `DADOS_PASTA` (padrão `dados/`).
  Estrutura e regras: `docs/ANALISE_DADOS.md`. Os números deste relatório continuam valendo: a leitura
  em Node reproduz as mesmas conferências (`npm run importar-dados -- --conferir`).
- **Envio de dados**: pela aba "Enviar dados". Aceita o HTML do Smart Report e planilha CSV (primeira
  coluna `data`, demais com o nome do campo). Cada envio fica em `dados/enviados/<data-hora>/`. Depois de
  cada envio a pasta inteira é relida e o banco fica igual a ela. Arquivo repetido é ignorado; arquivo com
  layout diferente é recusado com o motivo, sem derrubar os outros.
- **Receita de catraca**: os campos `receitaCatracaDinheiro` e `receitaCatracaCartao` existem no banco e no
  painel, mas só são preenchidos por planilha CSV. Sem ela aparecem como "sem dado", nunca como zero.
- **Banco**: MongoDB, que o projeto já usava. `indicadordiarios` (1 documento por data), `importacaodados`
  (arquivos lidos e conferências de cada leitura) e `feriados`. Índice único `data + linha`, com `linha`
  nulo para o agregado: detalhar por linha depois é só gravar documentos com a linha preenchida.
- **Cálculo no backend**: a tela só exibe; somas, médias, acumulado e alerta ficam num lugar só.
- **Gráficos**: desenhados com `CustomPainter`, sem biblioteca nova. Um eixo por gráfico.
- **Kafka e e-mail removidos**: a entrada de dados é só o upload de arquivos (ou a pasta `dados/`).
- **Viagens uma a uma** (atualizado em 03/10/2026): `viagensrealizadas` e `viagensnaocumpridas` alimentam
  a aba **Operação** (por linha, por hora, frota, turnos, não cumpridas, pesquisa). Resumo por Linha e
  as duas Faixas Horárias são conferidos contra as viagens em vez de gravados (são deriváveis delas).
- **Dependências novas**: `exceljs` (XLSX) no backend; `web` no frontend (já vinha com o `http`).
- **Fora do escopo agora**: leitura de XLSX/PDF como entrada.

## 13. Estrutura do painel

Aba **Enviar dados**: escolher arquivos, enviar, ver o que cada arquivo virou (usado no painel, usado na
conferência, não reconhecido, repetido ou recusado).

Aba **Verificação** (filtros de período e tipo de dia no topo, valendo para a tela e para as exportações;
por padrão só "Dias úteis" vem marcado):

| Módulo | Na tela | Limitação com os dados atuais |
|---|---|---|
| 1. Demanda diária | 3 curvas (demanda total, pagantes, gratuitos); botão linha/barras; estatísticas por tipo de dia e dia da semana; pico da semana | passageiros só a partir de 15/07 |
| 2. Receita diária | gráfico e tabela por mês: receita antecipada, catraca em dinheiro, catraca em cartão | catraca fica "sem dado" até chegar a planilha CSV |
| 3. Crédito circulante | painel de alerta (sem alerta / amarelo / vermelho), acumulado, tabela por semana, pontos de atenção | sem saldo inicial; limites do alerta adotados pelo projeto |
| Quilometragem | colunas produtiva + improdutiva, cumprimento de viagens, relatório para impressão/PDF | sem km programada |
| 4. Exportação | XLSX e CSV dos dados filtrados, quilometragem em XLSX/CSV, PNG de cada gráfico | |
| Conferência | os 19 cruzamentos entre os arquivos | |
