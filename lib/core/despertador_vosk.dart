import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'despertador.dart';

// En Android, «Oye NANA» usa Vosk: escucha sin parar, sin el «bip» del
// sistema y sin internet. En iPhone (Vosk no lo soporta) se usa el de antes.
Despertador crearDespertador() =>
    Platform.isAndroid ? DespertadorVosk() : DespertadorConVoz();

// El modelo de voz en español viene dentro de la app (assets/models). La
// primera vez se descomprime en el celular (unos segundos); después ya no.
const _modelo = 'assets/models/vosk-model-small-es-0.42.zip';

// Lo único que puede «oír»: con una lista cerrada no confunde la plática
// de la casa ni la tele con «Oye NANA». [unk] = cualquier otra cosa.
const _gramatica = [
  'oye nana',
  'oiga nana',
  'hola nana',
  'oye ana',
  'oye nena',
  '[unk]',
];

class DespertadorVosk implements Despertador {
  final _activo = ValueNotifier(false);
  VoidCallback? _alOir;
  bool _quiere = false;

  Future<SpeechService?>? _preparando;
  SpeechService? _servicio;

  // Si Vosk no arranca en este celular, el de antes (con bip) para que
  // «Oye NANA» siga funcionando.
  DespertadorConVoz? _respaldo;

  @override
  ValueListenable<bool> get activo => _activo;

  Future<SpeechService?> _preparar() => _preparando ??= () async {
    try {
      final vosk = VoskFlutterPlugin.instance();
      final ruta = await ModelLoader().loadFromAssets(_modelo);
      final modelo = await vosk.createModel(ruta);
      final reconocedor = await vosk.createRecognizer(
        model: modelo,
        sampleRate: 16000,
        grammar: _gramatica,
      );
      final s = await vosk.initSpeechService(reconocedor);
      // Los parciales avisan en cuanto se oye; el resultado, al terminar.
      s.onPartial().listen((j) => _revisar(j, 'partial'));
      s.onResult().listen((j) => _revisar(j, 'text'));
      return s;
    } catch (e) {
      debugPrint('NANA: Vosk no arrancó, uso el reconocimiento de antes: $e');
      return null;
    }
  }();

  void _revisar(String json, String campo) {
    if (!_quiere) return;
    String texto;
    try {
      texto = ((jsonDecode(json) as Map)[campo] as String?) ?? '';
    } catch (_) {
      return;
    }
    if (!esDespertar(texto)) return;
    debugPrint('NANA «Oye NANA» (Vosk): "$texto"');
    final f = _alOir;
    _alOir = null;
    _quiere = false;
    _activo.value = false;
    // Suelta el micrófono antes de abrir la plática, que lo necesita.
    _servicio?.stop().whenComplete(() => f?.call());
  }

  @override
  Future<void> empezar(VoidCallback alOir) async {
    _alOir = alOir;
    _quiere = true;
    final s = await _preparar();
    if (!_quiere) return; // lo pararon mientras se preparaba
    if (s == null) {
      final r = _respaldo ??= DespertadorConVoz()
        ..activo.addListener(() => _activo.value = _respaldo!.activo.value);
      await r.empezar(() {
        _quiere = false;
        final f = _alOir;
        _alOir = null;
        f?.call();
      });
      return;
    }
    _servicio = s;
    try {
      await s.reset();
      await s.start();
      _activo.value = _quiere;
    } catch (e) {
      debugPrint('NANA: Vosk no pudo escuchar: $e');
      _activo.value = false;
    }
  }

  @override
  Future<void> parar() async {
    _quiere = false;
    _alOir = null;
    _activo.value = false;
    await _respaldo?.parar();
    try {
      await _servicio?.stop();
    } catch (_) {}
  }
}
