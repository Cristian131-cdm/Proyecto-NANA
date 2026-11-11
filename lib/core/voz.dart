import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'ajustes.dart';

// La voz de NANA: habla con la voz del celular (sin internet, gratis) y
// escucha frases cortas. Lo que oye se compara con listas fijas (ver
// entender() abajo): aquí no hay IA, así que el registro de medicinas nunca
// depende de un modelo.
abstract class Voz {
  // Para que la mascota mueva la boca o muestre que escucha.
  ValueListenable<bool> get hablando;
  ValueListenable<bool> get escuchando;

  Future<void> decir(String texto);
  Future<void> callar();

  // Escucha una sola frase y regresa lo que entendió, o null si no oyó nada,
  // no hay micrófono o la persona no dio permiso.
  Future<String?> escuchar({Duration maximo = const Duration(seconds: 8)});
  Future<void> dejarDeEscuchar();
}

// En pruebas y en web: no suena nada, pero recuerda qué se dijo y puede
// "oír" lo que la prueba le ponga en [respuestas].
class VozNula implements Voz {
  final List<String> dicho = [];
  final List<String?> respuestas = [];
  final _hablando = ValueNotifier(false);
  final _escuchando = ValueNotifier(false);

  VozNula({List<String?> respuestas = const []}) {
    this.respuestas.addAll(respuestas);
  }

  @override
  ValueListenable<bool> get hablando => _hablando;
  @override
  ValueListenable<bool> get escuchando => _escuchando;

  @override
  Future<void> decir(String texto) async => dicho.add(texto);
  @override
  Future<void> callar() async {}
  @override
  Future<String?> escuchar({
    Duration maximo = const Duration(seconds: 8),
  }) async => respuestas.isEmpty ? null : respuestas.removeAt(0);
  @override
  Future<void> dejarDeEscuchar() async {}
}

class VozCelular implements Voz {
  final _tts = FlutterTts();
  final _oido = SpeechToText();
  final _hablando = ValueNotifier(false);
  final _escuchando = ValueNotifier(false);
  bool _ttsListo = false;
  bool? _oidoListo;
  Completer<String?>? _espera;

  @override
  ValueListenable<bool> get hablando => _hablando;
  @override
  ValueListenable<bool> get escuchando => _escuchando;

  Future<void> _prepararTts() async {
    if (_ttsListo) return;
    _ttsListo = true;
    await _tts.setLanguage('es-MX');
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _hablando.value = true);
    _tts.setCompletionHandler(() => _hablando.value = false);
    _tts.setCancelHandler(() => _hablando.value = false);
    _tts.setErrorHandler((_) => _hablando.value = false);
  }

  @override
  Future<void> decir(String texto) async {
    if (texto.trim().isEmpty) return;
    try {
      await _prepararTts();
      // Ajustes.velocidadVoz va de 0.5 (despacio) a 1.5 (rápido); el plugin
      // usa 0.5 como velocidad "normal" en Android y iOS.
      await _tts.setSpeechRate(0.5 * Ajustes.velocidadVoz.value);
      await _tts.stop();
      await _tts.speak(texto);
    } catch (e) {
      debugPrint('NANA no pudo hablar: $e');
      _hablando.value = false;
    }
  }

  @override
  Future<void> callar() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _hablando.value = false;
  }

  @override
  Future<String?> escuchar({
    Duration maximo = const Duration(seconds: 8),
  }) async {
    try {
      _oidoListo ??= await _oido.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus ||
              s == SpeechToText.notListeningStatus) {
            _terminar(null);
          }
        },
        onError: (_) => _terminar(null),
      );
      if (_oidoListo != true) return null;
      // No escucha mientras ella misma habla.
      await callar();
      final espera = _espera = Completer<String?>();
      _escuchando.value = true;
      await _oido.listen(
        onResult: (r) {
          if (r.finalResult) _terminar(r.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: 'es_MX',
          listenFor: maximo,
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          // Se reconoce en el celular: la voz no sale del aparato.
          onDevice: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
      return await espera.future.timeout(
        maximo + const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('NANA no pudo escuchar: $e');
      return null;
    } finally {
      _escuchando.value = false;
    }
  }

  void _terminar(String? texto) {
    final e = _espera;
    if (e != null && !e.isCompleted) {
      e.complete(texto == null || texto.trim().isEmpty ? null : texto);
    }
    _escuchando.value = false;
  }

  @override
  Future<void> dejarDeEscuchar() async {
    try {
      await _oido.stop();
    } catch (_) {}
    _terminar(null);
  }
}

// ---------- Entender sin IA ----------

// Minúsculas, sin acentos ni signos: "¿Ya me la TOMÉ?" → "ya me la tome".
String normalizar(String s) {
  const con = 'áéíóúüñ';
  const sin = 'aeiouun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = con.indexOf(c);
    b.write(i >= 0 ? sin[i] : c);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

// Busca qué intención contiene lo que se oyó. Las intenciones se revisan en
// orden y gana la primera, así que las frases negativas ("todavía no") deben
// ir antes que las positivas que contienen ("no" frente a "ya").
T? entender<T>(String? oido, List<(T, List<String>)> intenciones) {
  if (oido == null) return null;
  final t = ' ${normalizar(oido)} ';
  for (final (intencion, frases) in intenciones) {
    for (final f in frases) {
      if (t.contains(' ${normalizar(f)} ')) return intencion;
    }
  }
  return null;
}

enum RespuestaRecordatorio { si, alRato }

// Lo que se puede contestar en el recordatorio de una medicina.
const respuestasRecordatorio = <(RespuestaRecordatorio, List<String>)>[
  (
    RespuestaRecordatorio.alRato,
    [
      'al rato',
      'ahorita no',
      'todavia no',
      'aun no',
      'mas tarde',
      'despues',
      'luego',
      'no',
      'espera',
    ],
  ),
  (
    RespuestaRecordatorio.si,
    [
      'ya me la tome',
      'ya me lo tome',
      'ya la tome',
      'ya lo hice',
      'ya',
      'si',
      'listo',
      'claro',
      'hecho',
    ],
  ),
];
