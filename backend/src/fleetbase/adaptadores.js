// Converte os dados do PROJETOBUS para o formato que a API do Fleetbase espera.
// Se o Fleetbase mudar algum campo, só este arquivo precisa mudar.

function veiculoParaFleetbase(veiculo) {
  return {
    name: veiculo.prefixo ? `${veiculo.prefixo} - ${veiculo.placa}` : veiculo.placa,
    plate_number: veiculo.placa,
    call_sign: veiculo.prefixo || undefined,
    make: veiculo.marca || undefined,
    model: veiculo.modelo || undefined,
    year: veiculo.ano || undefined,
    seating_capacity: veiculo.capacidade || undefined,
    odometer: veiculo.hodometro || undefined,
    type: 'bus',
    meta: { projetobus_id: String(veiculo._id) }
  };
}

function motoristaParaFleetbase(usuario) {
  return {
    name: usuario.nome,
    email: usuario.email || undefined,
    phone: usuario.telefone || undefined,
    drivers_license_number: usuario.cnh || undefined,
    meta: { projetobus_id: String(usuario._id) }
  };
}

// velocidade/direção vêm do celular em m/s e graus, que é o que o Fleetbase guarda
function posicaoParaFleetbase(posicao) {
  return {
    latitude: posicao.latitude,
    longitude: posicao.longitude,
    speed: posicao.velocidade ?? undefined,
    heading: posicao.direcao ?? undefined
  };
}

module.exports = { veiculoParaFleetbase, motoristaParaFleetbase, posicaoParaFleetbase };
