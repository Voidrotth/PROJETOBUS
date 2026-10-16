// Catálogo dos relatórios do Smart Report, tirado da análise de dados/ (docs/ANALISE_DADOS.md).
// É o modelo único: a identificação, a IA, o validador e o banco usam estes nomes de campo.
//
// Cada campo: [coluna no relatório, tipo, obrigatório?, descrição para a IA]
// Tipos: data (dd/mm/aaaa) | mes (aaaa-mm) | dia (01–31) | inteiro | decimal | texto | datahora | faixa ("4hs" ou "4")

const MODELOS = {
  resumoGeral: {
    descricao: 'Resumo Geral: um dia por linha com veículos, viagens programadas/realizadas e quilometragem',
    titulo: /Resumo Geral$/i,
    campos: {
      data: ['Data', 'data', true, 'data do dia'],
      diaSemana: ['diaSem', 'texto', true, 'dia da semana abreviado (Seg, Ter...)'],
      veiculos: ['nrVeiculos', 'inteiro', true, 'veículos que operaram no dia'],
      maxVeiculosFaixa: ['nrMaxVeicFx', 'inteiro', true, 'maior número de veículos numa mesma hora'],
      viagensProgramadas: ['nrViagensProgr', 'inteiro', true, 'viagens programadas'],
      viagensRealizadas: ['nrViagensRealiz', 'inteiro', true, 'viagens realizadas'],
      viagensNaoCumpridas: ['Dif Viagens', 'inteiro', true, 'programadas menos realizadas'],
      kmProdutiva: ['kmProd', 'decimal', true, 'km produtiva'],
      kmImprodutiva: ['kmImprod', 'decimal', true, 'km improdutiva'],
      kmTotal: ['kmTotal', 'decimal', true, 'km total']
    }
  },
  cumprimento: {
    descricao: 'Fator de Cumprimento de Viagem: viagens programadas e realizadas por turno (manhã, tarde, noite) por dia',
    titulo: /Cumprimento de Viagem$/i,
    campos: {
      data: ['Data', 'data', true, 'data do dia'],
      manhaProgramadas: ['manha_p', 'inteiro', true, 'programadas de manhã'],
      manhaRealizadas: ['manha_r', 'inteiro', true, 'realizadas de manhã'],
      tardeProgramadas: ['tarde_p', 'inteiro', true, 'programadas à tarde'],
      tardeRealizadas: ['tarde_r', 'inteiro', true, 'realizadas à tarde'],
      noiteProgramadas: ['noite_p', 'inteiro', true, 'programadas à noite'],
      noiteRealizadas: ['noite_r', 'inteiro', true, 'realizadas à noite'],
      programadas: ['programadas', 'inteiro', true, 'total programadas no dia'],
      realizadas: ['realizadas', 'inteiro', true, 'total realizadas no dia']
    }
  },
  resumoLinha: {
    descricao: 'Resumo por Linha: por dia e linha de ônibus, km produtiva e número de viagens',
    titulo: /Resumo por Linha$/i,
    campos: {
      data: ['Data', 'data', true, 'data do dia'],
      linha: ['Linha', 'texto', true, 'código da linha (01, 02...)'],
      kmProdutiva: ['kmTotal', 'decimal', true, 'km da linha no dia (é a km produtiva, apesar do nome kmTotal)'],
      viagens: ['nrViagens', 'inteiro', true, 'viagens realizadas na linha']
    }
  },
  partidasFaixa: {
    descricao: 'Partidas por Faixa Horária: por dia, linha e hora, veículos, viagens e minutos das partidas',
    titulo: /Partidas por Faixa Hor[aá]ria$/i,
    campos: {
      data: ['Data', 'data', true, 'data do dia'],
      linha: ['Linha', 'texto', true, 'código da linha'],
      hora: ['Fx_Hor', 'faixa', true, 'hora do dia (ex.: 4hs)'],
      veiculos: ['Nr_Veiculos', 'inteiro', true, 'veículos na hora'],
      viagens: ['Nr_Viagens', 'inteiro', true, 'viagens iniciadas na hora'],
      partidas: ['Partidas', 'texto', true, 'minutos das partidas separados por >']
    }
  },
  resumoFaixa: {
    descricao: 'Resumo por Faixa Horária: por dia e hora, veículos e viagens (todas as linhas)',
    titulo: /Resumo por Faixa Hor[aá]ria$/i,
    campos: {
      data: ['Data', 'data', true, 'data do dia'],
      hora: ['Fx_Hor', 'faixa', true, 'hora do dia (ex.: 4hs)'],
      veiculos: ['Nr_Veiculos', 'inteiro', true, 'veículos na hora'],
      viagens: ['Nr_Viagens', 'inteiro', true, 'viagens iniciadas na hora']
    }
  },
  viagens: {
    descricao: 'Viagens: uma linha por viagem realizada (ou por veículo/dia quando a atividade é improdutiva)',
    titulo: /- Viagens$/i,
    campos: {
      data: ['Data', 'data', true, 'dia operacional'],
      linha: ['Linha', 'texto', false, 'código da linha (vazio nas improdutivas)'],
      prefixo: ['Prefixo', 'texto', true, 'número do ônibus'],
      atividade: ['Atividade', 'texto', true, '"Viagem Normal" ou "Improdutivas"'],
      sentido: ['Sentido', 'texto', false, 'I (ida) ou V (volta)'],
      hora: ['Fx_Hor', 'faixa', true, 'hora de início da viagem'],
      inicio: ['inicioRealizado', 'datahora', false, 'início realizado'],
      fim: ['fimRealizado', 'datahora', false, 'fim realizado'],
      kmProdutiva: ['kmProd', 'decimal', true, 'km produtiva'],
      kmImprodutiva: ['kmImprod', 'decimal', true, 'km improdutiva'],
      kmTotal: ['kmTotal', 'decimal', true, 'km total']
    }
  },
  // Os três relatórios de viagens não cumpridas têm as mesmas colunas: o título decide
  ...Object.fromEntries([
    ['naoRealizadas', /n[aã]o Realizadas$/i, 'Viagens não Realizadas: viagem programada que não saiu'],
    ['naoIniciadas', /n[aã]o Iniciadas$/i, 'Viagens não Iniciadas: viagem programada sem registro de início'],
    ['naoTerminadas', /n[aã]o Terminadas$/i, 'Viagens não Terminadas: viagem iniciada sem registro de fim']
  ].map(([tipo, titulo, descricao]) => [tipo, {
    descricao,
    titulo,
    campos: {
      data: ['Data', 'data', true, 'data do dia'],
      linha: ['Linha', 'texto', true, 'código da linha'],
      atendimento: ['Atendimento', 'texto', true, 'nome do itinerário e sentido'],
      prefixo: ['Prefixo', 'texto', false, 'número do ônibus'],
      motorista: ['Motorista', 'texto', true, 'matrícula do motorista'],
      sentido: ['Sentido', 'texto', true, 'I (ida) ou V (volta)'],
      tabela: ['Tabela', 'texto', true, 'escala do veículo (1A, 3B...)'],
      statusSaida: ['statusSaida', 'texto', false, 'código de status da saída'],
      statusChegada: ['statusChegada', 'texto', false, 'código de status da chegada'],
      inicioProgramado: ['inicioProgramado', 'datahora', true, 'início programado'],
      inicioRealizado: ['inicioRealizado', 'datahora', false, 'início realizado'],
      fimProgramado: ['fimProgramado', 'datahora', true, 'fim programado'],
      fimRealizado: ['fimRealizado', 'datahora', false, 'fim realizado']
    }
  }])),
  passageiros: {
    descricao: 'Passageiros do Sistema: por dia, passageiros na catraca, antecipados, não pagantes e total',
    titulo: /Passageiros do Sistema$/i,
    campos: {
      mes: ['Mês', 'mes', true, 'mês aaaa-mm'],
      dia: ['Dia', 'dia', true, 'dia do mês'],
      catraca: ['Catraca', 'inteiro', true, 'passageiros pagantes na catraca'],
      antecipados: ['Antecipados', 'inteiro', true, 'passageiros com crédito antecipado'],
      naoPagantes: ['Não Pagantes', 'inteiro', true, 'gratuidades'],
      passageiros: ['Total Passageiros', 'inteiro', true, 'total de passageiros']
    }
  },
  saldo: {
    descricao: 'Saldo de créditos do sistema: por dia, créditos transferidos para cartões e saldo final (R$)',
    titulo: /Saldo de cr[eé]ditos do sistema$/i,
    campos: {
      mes: ['Mês', 'mes', true, 'mês aaaa-mm'],
      dia: ['Dia', 'dia', true, 'dia do mês'],
      serie: ['Série', 'texto', false, 'série (sempre 1)'],
      // Pode vir vazio (02/08 no quinzenal de agosto): fica nulo, não zero
      transferidos: ['Créditos transferidos para cartões', 'decimal', false, 'R$ transferidos para cartões'],
      saldoFinal: ['Saldo Final', 'decimal', true, 'R$ de saldo no fim do dia']
    }
  },
  creditos: {
    descricao: 'Venda x Utilização: por dia, R$ de créditos vendidos, utilizados e o crédito circulante',
    titulo: /Venda x Utiliza[cç][aã]o$/i,
    campos: {
      mes: ['Mês', 'mes', true, 'mês aaaa-mm'],
      dia: ['Dia', 'dia', true, 'dia do mês'],
      vendas: ['Total Vendas', 'decimal', true, 'R$ vendidos'],
      utilizacao: ['Total Utilização', 'decimal', true, 'R$ utilizados'],
      circulante: ['Crédito Circulante', 'decimal', true, 'vendas menos utilização (pode ser negativo)']
    }
  }
};

const NAO_CUMPRIDAS = { naoRealizadas: 'nao_realizada', naoIniciadas: 'nao_iniciada', naoTerminadas: 'nao_terminada' };

module.exports = { MODELOS, NAO_CUMPRIDAS };
