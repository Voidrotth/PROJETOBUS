import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'servico_api.dart';

/// Captura o GPS durante a viagem e envia ao backend em lotes.
///
/// - Cada posição vai primeiro para uma fila salva no aparelho; sem internet,
///   a fila cresce e é enviada quando a conexão voltar (ou o app reabrir).
/// - No Android roda como serviço em primeiro plano (notificação fixa), então
///   continua funcionando com a tela desligada.
/// - Poucas requisições: um lote a cada [intervaloEnvio].
class RastreadorGps extends ChangeNotifier {
  RastreadorGps._();
  static final RastreadorGps instancia = RastreadorGps._();

  static const intervaloEnvio = Duration(seconds: 10);
  static const _distanciaMinimaMetros = 20;
  static const _tamanhoLote = 200;
  static const _maximoNaFila = 20000;

  String? _viagemId;
  // Transmissão sem login ("Sou motorista"): token próprio, renovado quando vence
  String? _token;
  Future<String> Function()? _renovarToken;
  StreamSubscription<Position>? _assinatura;
  Timer? _temporizador;
  bool _enviando = false;
  List<Map<String, dynamic>> _fila = [];

  Position? ultimaPosicao;
  DateTime? ultimoEnvio;
  bool conectado = true;
  String? erro;

  bool get rastreando => _assinatura != null;
  int get pendentes => _fila.length;

  String get _chaveFila => 'fila_gps_$_viagemId';

  /// Pede permissão de localização. Retorna a mensagem de erro, ou null se estiver tudo certo.
  static Future<String?> verificarPermissao() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Ative a localização (GPS) do celular';
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied) {
      return 'Permissão de localização negada';
    }
    if (permissao == LocationPermission.deniedForever) {
      return 'Permissão de localização bloqueada. Libere nas configurações do celular.';
    }
    return null;
  }

  Future<void> iniciar(String viagemId, {String? token, Future<String> Function()? renovarToken}) async {
    _token = token;
    _renovarToken = renovarToken;
    if (_viagemId == viagemId && rastreando) return;
    await parar(limparFila: false);

    _viagemId = viagemId;
    erro = null;
    await _carregarFila();

    _assinatura = Geolocator.getPositionStream(locationSettings: _configuracaoGps()).listen(
      _aoReceberPosicao,
      onError: (e) {
        erro = 'Falha no GPS: $e';
        notifyListeners();
      },
    );
    _temporizador = Timer.periodic(intervaloEnvio, (_) => enviarFila());
    notifyListeners();
    enviarFila();
  }

  /// Para o GPS. Com [limparFila] apaga o que não foi enviado (usar só após encerrar a viagem).
  Future<void> parar({bool limparFila = true}) async {
    await _assinatura?.cancel();
    _assinatura = null;
    _temporizador?.cancel();
    _temporizador = null;
    if (limparFila && _viagemId != null) {
      _fila = [];
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.remove(_chaveFila);
      _viagemId = null;
    }
    notifyListeners();
  }

  LocationSettings _configuracaoGps() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanciaMinimaMetros,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'PROJETOBUS - viagem em andamento',
          notificationText: 'Enviando a localização do ônibus',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanciaMinimaMetros,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanciaMinimaMetros);
  }

  void _aoReceberPosicao(Position posicao) {
    ultimaPosicao = posicao;
    erro = null;
    _fila.add({
      'latitude': posicao.latitude,
      'longitude': posicao.longitude,
      'velocidade': posicao.speed,
      'direcao': posicao.heading,
      'precisao': posicao.accuracy,
      'horario': posicao.timestamp.toUtc().toIso8601String(),
    });
    if (_fila.length > _maximoNaFila) {
      _fila.removeRange(0, _fila.length - _maximoNaFila);
    }
    _salvarFila();
    notifyListeners();
  }

  /// Envia a fila em lotes. Se falhar, os pontos continuam guardados para a próxima tentativa.
  Future<bool> enviarFila() async {
    final viagemId = _viagemId;
    if (viagemId == null || _enviando) return false;
    _enviando = true;
    try {
      while (_fila.isNotEmpty) {
        final lote = _fila.take(_tamanhoLote).toList();
        await ServicoApi.enviarPosicoes(viagemId, lote, token: _token);
        // Novos pontos só entram no fim da fila, então remover do início é seguro
        _fila.removeRange(0, lote.length);
        await _salvarFila();
        ultimoEnvio = DateTime.now();
      }
      conectado = true;
      return true;
    } catch (e) {
      // Token da transmissão venceu: pega outro (a mesma viagem continua) e reenvia no próximo ciclo
      if (e is ErroApi && e.status == 401 && _renovarToken != null) {
        try {
          _token = await _renovarToken!();
        } catch (_) {}
      }
      // O backend recusou o lote (ex.: viagem não existe mais): não adianta reenviar.
      // 401 (sessão expirada) não entra aqui: os pontos seguem válidos após novo login.
      if (e is ErroApi && const [400, 403, 404].contains(e.status)) {
        _fila = [];
        await _salvarFila();
        erro = e.mensagem;
      }
      conectado = false;
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<void> _carregarFila() async {
    final preferencias = await SharedPreferences.getInstance();
    final salva = preferencias.getString(_chaveFila);
    _fila = salva == null ? [] : (jsonDecode(salva) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _salvarFila() async {
    if (_viagemId == null) return;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_chaveFila, jsonEncode(_fila));
  }
}
