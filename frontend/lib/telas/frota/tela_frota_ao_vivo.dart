import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../servicos/servico_api.dart';
import '../../servicos/sessao.dart';

/// Mapa com os ônibus em viagem. Estado inicial via API; atualizações via Socket.IO do backend.
class TelaFrotaAoVivo extends StatefulWidget {
  const TelaFrotaAoVivo({super.key});

  @override
  State<TelaFrotaAoVivo> createState() => _TelaFrotaAoVivoEstado();
}

class _TelaFrotaAoVivoEstado extends State<TelaFrotaAoVivo> {
  static const _centroPadrao = LatLng(-15.79, -47.88);

  final _mapa = MapController();
  final Map<String, Map<String, dynamic>> _viagens = {};
  io.Socket? _socket;
  bool _conectado = false;
  String? _selecionada;
  List<LatLng> _trajeto = [];
  String? _erro;
  // O MapController só pode ser usado depois que o mapa aparece na tela
  bool _mapaPronto = false;
  LatLng? _centroPendente;

  @override
  void initState() {
    super.initState();
    _carregar();
    _conectarTempoReal();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final viagens = await ServicoApi.viagensAoVivo();
      if (!mounted) return;
      setState(() {
        _erro = null;
        _viagens
          ..clear()
          ..addEntries(viagens.map((v) => MapEntry(v['viagemId'] as String, v)));
      });
      final primeira = _viagens.values.map(_ponto).whereType<LatLng>().firstOrNull;
      if (primeira != null && _selecionada == null) _centralizar(primeira, 13);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  void _centralizar(LatLng ponto, double zoom) {
    if (_mapaPronto) {
      _mapa.move(ponto, zoom);
    } else {
      _centroPendente = ponto;
    }
  }

  void _conectarTempoReal() {
    final socket = io.io(
      ServicoApi.urlServidor,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': Sessao.token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );
    socket.onConnect((_) {
      if (mounted) setState(() => _conectado = true);
      _carregar(); // recupera o que mudou enquanto estava desconectado
    });
    socket.onDisconnect((_) {
      if (mounted) setState(() => _conectado = false);
    });
    socket.on('viagem:iniciada', _atualizarViagem);
    socket.on('viagem:posicao', _atualizarViagem);
    socket.on('viagem:encerrada', (dados) {
      if (!mounted) return;
      final id = dados['viagemId'] as String;
      setState(() {
        _viagens.remove(id);
        if (_selecionada == id) {
          _selecionada = null;
          _trajeto = [];
        }
      });
    });
    socket.connect();
    _socket = socket;
  }

  void _atualizarViagem(dynamic dados) {
    if (!mounted) return;
    final viagem = Map<String, dynamic>.from(dados as Map);
    setState(() {
      _viagens[viagem['viagemId']] = viagem;
      final ponto = _ponto(viagem);
      if (viagem['viagemId'] == _selecionada && ponto != null) _trajeto = [..._trajeto, ponto];
    });
  }

  LatLng? _ponto(Map<String, dynamic> viagem) {
    final posicao = viagem['ultimaPosicao'];
    if (posicao == null) return null;
    return LatLng((posicao['latitude'] as num).toDouble(), (posicao['longitude'] as num).toDouble());
  }

  String _nomeVeiculo(Map<String, dynamic> viagem) {
    final veiculo = viagem['veiculo'] ?? {};
    final prefixo = veiculo['prefixo'] ?? '';
    return prefixo.isNotEmpty ? prefixo : (veiculo['placa'] ?? '?');
  }

  Future<void> _selecionar(String viagemId) async {
    setState(() {
      _selecionada = viagemId;
      _trajeto = [];
    });
    final ponto = _ponto(_viagens[viagemId]!);
    if (ponto != null) _centralizar(ponto, 15);
    try {
      final pontos = await ServicoApi.trajeto(viagemId);
      if (mounted && _selecionada == viagemId) {
        setState(() => _trajeto = pontos
            .map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()))
            .toList());
      }
    } catch (_) {
      // Sem trajeto: o mapa continua mostrando a posição atual
    }
  }

  @override
  Widget build(BuildContext context) {
    final viagens = _viagens.values.toList()..sort((a, b) => _nomeVeiculo(a).compareTo(_nomeVeiculo(b)));

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text('Frota ao vivo', style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text('${viagens.length} ônibus em viagem'),
                trailing: Tooltip(
                  message: _conectado ? 'Tempo real conectado' : 'Tempo real desconectado',
                  child: Icon(Icons.circle, size: 14, color: _conectado ? Colors.green : Colors.red),
                ),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: viagens.map((viagem) {
                    final posicao = viagem['ultimaPosicao'];
                    final horario = DateTime.tryParse(posicao?['horario'] ?? '')?.toLocal();
                    return ListTile(
                      selected: viagem['viagemId'] == _selecionada,
                      leading: const Icon(Icons.directions_bus),
                      title: Text('${_nomeVeiculo(viagem)} · Linha ${viagem['linha']}'),
                      subtitle: Text([
                        viagem['motorista']?['nome'] ?? '',
                        horario == null ? 'sem posição ainda' : 'visto às ${DateFormat('HH:mm:ss').format(horario)}',
                      ].join('\n')),
                      isThreeLine: true,
                      onTap: () => _selecionar(viagem['viagemId']),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _centroPadrao,
              initialZoom: 4,
              onMapReady: () {
                _mapaPronto = true;
                if (_centroPendente != null) _mapa.move(_centroPendente!, 13);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.com.projetobus',
              ),
              if (_trajeto.length > 1)
                PolylineLayer(polylines: [Polyline(points: _trajeto, strokeWidth: 4, color: Colors.blue)]),
              MarkerLayer(
                markers: viagens.where((v) => _ponto(v) != null).map((viagem) {
                  final selecionada = viagem['viagemId'] == _selecionada;
                  return Marker(
                    point: _ponto(viagem)!,
                    width: 90,
                    height: 56,
                    child: GestureDetector(
                      onTap: () => _selecionar(viagem['viagemId']),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: selecionada ? Colors.blue : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
                            ),
                            child: Text(_nomeVeiculo(viagem),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selecionada ? Colors.white : Colors.black)),
                          ),
                          Icon(Icons.directions_bus, size: 30, color: selecionada ? Colors.blue : Colors.green.shade700),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
            ],
          ),
        ),
      ],
    );
  }
}
