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
  // no hay micrófono o la persona no dio permiso. [basta]: si lo que lleva
  // oído ya sirve (ej. ya dijo "me siento mal"), deja de escuchar en ese
  // momento en vez de esperar a que se calle. [sirve]: si lo que lleva oído
  // ya se entiende y no cambia en 1.5 s, se toma como terminado (con ruido de
  // fondo Android no nota el silencio y esperaría hasta [maximo]).
  Future<String?> escuchar({
    Duration maximo = const Duration(seconds: 8),
    bool Function(String parcial)? basta,
    bool Function(String parcial)? sirve,
  });
  Future<void> dejarDeEscuchar();

  // Por qué falló la última vez que escuchó (para mostrarlo), o null.
  String? get problema;
}

// Lo que se le dice a la persona según el error del reconocimiento.
String explicarProblema(String error) => switch (error) {
  'error_permission' || 'error_insufficient_permissions' =>
    'NANA no tiene permiso de usar el micrófono',
  'error_no_match' || 'error_speech_timeout' => 'No te escuché',
  'error_network' ||
  'error_network_timeout' ||
  'error_server' ||
  'error_server_disconnected' => 'No hay internet para entenderte',
  'error_busy' || 'error_recognizer_busy' => 'El micrófono está ocupado',
  'sin_reconocimiento' => 'Este celular no tiene reconocimiento de voz',
  _ => 'No pude escuchar',
};

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
  // Para las pruebas: cuántas veces se le pidió callarse o soltar el micrófono.
  int callado = 0;
  int soltado = 0;

  @override
  Future<void> callar() async => callado++;
  @override
  Future<String?> escuchar({
    Duration maximo = const Duration(seconds: 8),
    bool Function(String parcial)? basta,
    bool Function(String parcial)? sirve,
  }) async => respuestas.isEmpty ? null : respuestas.removeAt(0);
  @override
  Future<void> dejarDeEscuchar() async => soltado++;
  @override
  String? problema;
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
    // Se usa el motor de voz que tenga puesto el celular. (2026-11-25: forzar
    // el de Google dejó muda a NANA en el A72: sus voces en español aparecían
    // en la lista pero sin descargar, y el motor «hablaba» en silencio.)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        _motorDelCelular = '${await _tts.getDefaultEngine}';
        _motorActual = _motorDelCelular;
        debugPrint('NANA voz: motor $_motorDelCelular');
      } catch (_) {}
    }
    await _tts.setLanguage('es-MX');
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _hablando.value = true);
    _tts.setCompletionHandler(() => _hablando.value = false);
    _tts.setCancelHandler(() => _hablando.value = false);
    _tts.setErrorHandler((_) => _hablando.value = false);
    Ajustes.vozNana.addListener(() => _vozAplicada = null);
  }

  String? _vozAplicada;
  String? _motorDelCelular;
  String? _motorActual;
  static const _motorGoogle = 'com.google.android.tts';

  Future<List<Map<String, String>>> _voces() async {
    final voces = [
      for (final v in (await _tts.getVoices as List? ?? const []))
        if (v is Map) v.map((k, valor) => MapEntry('$k', '$valor')),
    ];
    debugPrint(
      'NANA voces ($_motorActual): ${voces.where(esVozEnEspanol).map((v) => '${v['name']}(${generoDeVoz(v) ?? '?'}${vozDescargada(v) ? '' : ', sin descargar'})').join(', ')}',
    );
    return voces;
  }

  Future<void> _usarMotor(String? motor) async {
    if (motor == null || motor == _motorActual) return;
    await _tts.setEngine(motor);
    await _tts.awaitSpeakCompletion(true);
    _motorActual = motor;
    debugPrint('NANA voz: cambio al motor $motor');
  }

  // Pone la voz de mujer u hombre que eligió la persona. Primero busca en el
  // motor del celular; si ahí no hay (Samsung no da su lista de voces), prueba
  // el de Google, pero solo con una voz YA DESCARGADA. Si tampoco, regresa al
  // motor del celular y cambia el tono.
  Future<void> _aplicarVoz() async {
    final genero = Ajustes.vozNana.value;
    if (_vozAplicada == genero) return;
    _vozAplicada = genero;
    try {
      // Primero el motor en el que ya está (no brinca de motor en cada cambio).
      var voz = elegirVoz(await _voces(), genero);
      if (voz == null &&
          defaultTargetPlatform == TargetPlatform.android &&
          ((await _tts.getEngines as List?)?.contains(_motorGoogle) ?? false)) {
        final otro = _motorActual == _motorGoogle
            ? _motorDelCelular
            : _motorGoogle;
        if (otro != null && otro != _motorActual) {
          final antes = _motorActual;
          await _usarMotor(otro);
          voz = elegirVoz(await _voces(), genero);
          if (voz == null) await _usarMotor(antes);
        }
      }
      if (voz != null) {
        await _tts.setVoice({'name': voz['name']!, 'locale': voz['locale']!});
        debugPrint('NANA voz: uso ${voz['name']} ($genero)');
      } else {
        await _tts.setLanguage('es-MX');
        debugPrint('NANA voz: no hay voz de $genero, solo cambio el tono');
      }
      // Con voz de verdad el tono queda normal (bajarlo la hacía sonar
      // robotizada). Solo sin voz de ese género se baja un poco.
      await _tts.setPitch(voz != null ? 1.0 : tonoDe(genero));
    } catch (e) {
      debugPrint('NANA voz: no pude cambiar la voz ($e)');
    }
  }

  @override
  Future<void> decir(String texto) async {
    if (texto.trim().isEmpty) return;
    try {
      await _prepararTts();
      await _aplicarVoz();
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
  String? problema;
  String? _error;
  // Si el reconocimiento sin internet no existe en este celular, se usa el
  // de Google con internet (solo manda la frase, no se guarda en NANA).
  bool _conInternet = false;

  // Errores que significan "este cel no reconoce sin internet".
  static const _faltaSinInternet = {
    'error_language_unavailable',
    'error_language_not_supported',
    'error_client',
    'error_server_disconnected',
    'error_cannot_check_support',
    'error_too_many_requests',
  };

  @override
  Future<String?> escuchar({
    Duration maximo = const Duration(seconds: 8),
    bool Function(String parcial)? basta,
    bool Function(String parcial)? sirve,
  }) async {
    problema = null;
    _basta = basta;
    _sirve = sirve;
    try {
      _oidoListo ??= await _oido.initialize(
        debugLogging: kDebugMode,
        onStatus: (s) {
          debugPrint('NANA oído: $s');
          // En Android "notListening" y "done" llegan ANTES de la frase
          // reconocida (hasta ~1 s después). Se le da un margen; si la frase
          // llega antes, ella termina la espera.
          if (s == SpeechToText.doneStatus) _terminarSiNoLlega();
        },
        onError: (e) {
          debugPrint(
            'NANA oído error: ${e.errorMsg} (permanente: ${e.permanent})',
          );
          _error = e.errorMsg;
          _terminar(null);
        },
      );
      if (_oidoListo != true) {
        problema = explicarProblema('sin_reconocimiento');
        return null;
      }
      // No escucha mientras ella misma habla.
      await callar();
      var oido = await _unaVez(maximo);
      if (oido == null && !_conInternet && _faltaSinInternet.contains(_error)) {
        debugPrint('NANA: sin reconocimiento sin internet, uso el de Google');
        _conInternet = true;
        oido = await _unaVez(maximo);
      }
      if (oido == null && _error != null) problema = explicarProblema(_error!);
      return oido;
    } catch (e) {
      debugPrint('NANA no pudo escuchar: $e');
      problema = explicarProblema('');
      return null;
    } finally {
      _escuchando.value = false;
    }
  }

  Future<String?> _unaVez(Duration maximo) async {
    _error = null;
    final espera = _espera = Completer<String?>();
    _escuchando.value = true;
    await _oido.listen(
      onResult: (r) {
        debugPrint('NANA oyó: "${r.recognizedWords}" final=${r.finalResult}');
        if (r.finalResult) {
          _terminar(r.recognizedWords);
        } else if (_basta?.call(r.recognizedWords) == true) {
          // Ya dijo algo que NANA entiende: no hace falta esperar más.
          _terminar(r.recognizedWords);
          _oido.stop();
        } else if (_sirve?.call(r.recognizedWords) == true) {
          // Se entiende: si no dice nada más en 1.5 s, ya terminó.
          final dicho = r.recognizedWords;
          _calma?.cancel();
          _calma = Timer(const Duration(milliseconds: 1500), () {
            if (identical(espera, _espera)) {
              _terminar(dicho);
              _oido.stop();
            }
          });
        } else {
          _calma?.cancel();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'es_MX',
        listenFor: maximo,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        // Primero en el celular, para que la voz no salga del aparato.
        onDevice: !_conInternet,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
    return espera.future.timeout(
      maximo + const Duration(seconds: 4),
      onTimeout: () => null,
    );
  }

  bool Function(String)? _basta;
  bool Function(String)? _sirve;
  Timer? _calma;

  void _terminarSiNoLlega() {
    final e = _espera;
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (identical(e, _espera)) _terminar(null);
    });
  }

  void _terminar(String? texto) {
    _calma?.cancel();
    final e = _espera;
    if (e != null && !e.isCompleted) {
      e.complete(texto == null || texto.trim().isEmpty ? null : texto);
    }
    _escuchando.value = false;
  }

  @override
  Future<void> dejarDeEscuchar() async {
    // Al parar, Android todavía entrega lo que alcanzó a oír; si no llega
    // nada en un momento, se da por terminado.
    try {
      await _oido.stop();
    } catch (_) {}
    _terminarSiNoLlega();
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

enum RespuestaAviso { avisar, cancelar, no }

// Lo que se puede contestar en «Voy a avisar a tu familia». Ante la duda se
// avisa: por eso "no estoy bien" va antes que "estoy bien", y un "no" a secas
// solo hace que NANA vuelva a preguntar (puede querer decir "no estoy bien").
const respuestasAviso = <(RespuestaAviso, List<String>)>[
  (
    RespuestaAviso.avisar,
    [
      'no estoy bien',
      'no me siento bien',
      'no me puedo',
      'no puedo',
      'no me dejes',
    ],
  ),
  (
    RespuestaAviso.cancelar,
    [
      'estoy bien',
      'ya estoy bien',
      'no pasa nada',
      'no fue nada',
      'cancela',
      'cancelar',
      'fue sin querer',
      'me equivoque',
      'no te preocupes',
      'no avises',
      'no les avises',
    ],
  ),
  (
    RespuestaAviso.avisar,
    [
      'avisales',
      'avisa',
      'avisale',
      'si',
      'ayuda',
      'ayudame',
      'auxilio',
      'ven',
      'vengan',
      'por favor',
      'rapido',
      'me duele',
    ],
  ),
  (RespuestaAviso.no, ['no']),
];

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

// ---------- Elegir la voz de NANA (mujer u hombre) ----------

bool esVozEnEspanol(Map<String, String> v) =>
    (v['locale'] ?? '').toLowerCase().startsWith('es');

// Solo cuando el celular no tiene voz de ese género (ej. Samsung sin Google):
// hombre un poco más grave. Más bajo de 0.8 suena robotizado.
double tonoDe(String genero) => genero == 'hombre' ? 0.8 : 1.0;

// Android marca con «notInstalled» las voces que existen pero no se han
// descargado: con esas el motor «habla» sin sonido.
bool vozDescargada(Map<String, String> v) =>
    !(v['features'] ?? '').toLowerCase().contains('notinstalled');

// Códigos de las voces de Google en español (nombre «es-us-x-sfb-local»).
// Revisar en el A72 con la línea «NANA voces:» del log.
// Solo lo confirmado de oído por Cris en el A72 (2026-11-25): sfb suena a
// mujer y esf a hombre. esc/esd (y las de España) no se confirmaron, así que
// no se usan: elegir mal es peor que no elegir.
const _vocesGoogle = {'sfb': 'mujer', 'esf': 'hombre'};

// 'mujer', 'hombre' o null si el nombre no lo dice.
String? generoDeVoz(Map<String, String> v) {
  final nombre = (v['name'] ?? '').toLowerCase();
  final rasgos = (v['features'] ?? '').toLowerCase();
  for (final t in [rasgos, nombre]) {
    if (t.contains('female')) return 'mujer';
    if (RegExp(r'(^|[^e])male').hasMatch(t)) return 'hombre';
  }
  // Samsung: «es-MX-SMTf00» (mujer) / «es-MX-SMTm00» (hombre).
  final samsung = RegExp(r'smt([fm])\d').firstMatch(nombre);
  if (samsung != null) return samsung.group(1) == 'f' ? 'mujer' : 'hombre';
  final google = RegExp(r'-x-([a-z]{3})').firstMatch(nombre);
  if (google != null) return _vocesGoogle[google.group(1)];
  return null;
}

// La mejor voz en español del género pedido: primero de México, luego de
// Estados Unidos y Latinoamérica, al final de España; las que funcionan sin
// internet antes que las de red.
Map<String, String>? elegirVoz(List<Map<String, String>> voces, String genero) {
  const orden = ['es-mx', 'es-us', 'es-419', 'es-es'];
  int lugar(Map<String, String> v) {
    final l = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
    final i = orden.indexWhere(l.startsWith);
    return i < 0 ? orden.length : i;
  }

  bool deRed(Map<String, String> v) =>
      (v['network_required'] ?? '') == '1' ||
      (v['network_required'] ?? '').toLowerCase() == 'true' ||
      (v['name'] ?? '').toLowerCase().contains('network');

  final candidatas =
      [
        for (final v in voces)
          if (esVozEnEspanol(v) &&
              vozDescargada(v) &&
              v['name'] != null &&
              generoDeVoz(v) == genero)
            v,
      ]..sort((a, b) {
        final porLugar = lugar(a).compareTo(lugar(b));
        if (porLugar != 0) return porLugar;
        return (deRed(a) ? 1 : 0).compareTo(deRed(b) ? 1 : 0);
      });
  return candidatas.isEmpty ? null : candidatas.first;
}
