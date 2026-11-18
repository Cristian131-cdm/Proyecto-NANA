import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'servicios.dart';
import 'voz.dart';

// «Oye NANA»: mientras NANA está abierta y en pantalla, espera esa frase y,
// al oírla, abre la plática. Solo con la app abierta (decisión del equipo,
// 18 nov 2026): al minimizarla o abrir otra pantalla se suelta el micrófono.
// Lo que se oye se reconoce dentro del celular; no se graba ni se guarda.
abstract class Despertador {
  // true mientras está esperando «Oye NANA» (para mostrarlo en pantalla).
  ValueListenable<bool> get activo;

  // Empieza a esperar. [alOir] se llama una vez, ya con el micrófono suelto.
  Future<void> empezar(VoidCallback alOir);
  Future<void> parar();
}

// Lo que cuenta como «Oye NANA». El reconocedor a veces oye "Ana" o "nena".
const frasesDespertar = [
  'oye nana',
  'oiga nana',
  'hola nana',
  'hey nana',
  'ey nana',
  'oye ana',
  'oye nena',
  'oye nanna',
  'oye mana',
];

bool esDespertar(String? oido) =>
    entender(oido, [(true, frasesDespertar)]) == true;

// En pruebas y en web: no escucha nada. Las pruebas llaman a [oir()].
class DespertadorNulo implements Despertador {
  final _activo = ValueNotifier(false);
  VoidCallback? _alOir;
  int empezado = 0;
  int parado = 0;

  @override
  ValueListenable<bool> get activo => _activo;

  @override
  Future<void> empezar(VoidCallback alOir) async {
    empezado++;
    _alOir = alOir;
    _activo.value = true;
  }

  @override
  Future<void> parar() async {
    parado++;
    _alOir = null;
    _activo.value = false;
  }

  // Como si la persona hubiera dicho «Oye NANA».
  void oir() {
    final f = _alOir;
    if (f == null) return;
    _alOir = null;
    _activo.value = false;
    f();
  }
}

// Usa el mismo reconocimiento de voz de NANA (speech_to_text, dentro del
// celular) en vueltas cortas. No necesita paquetes nuevos. En Android cada
// vuelta puede sonar el "bip" del sistema; si molesta, esta pieza se cambia
// por un detector dedicado (Vosk) sin tocar las pantallas.
class DespertadorConVoz implements Despertador {
  final _activo = ValueNotifier(false);
  VoidCallback? _alOir;
  bool _corriendo = false;

  @override
  ValueListenable<bool> get activo => _activo;

  @override
  Future<void> empezar(VoidCallback alOir) async {
    _alOir = alOir;
    if (_corriendo) return;
    _corriendo = true;
    _activo.value = true;
    var fallas = 0;
    try {
      while (_corriendo) {
        // Nunca encima de NANA hablando: escuchar la callaría.
        if (Servicios.voz.hablando.value) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        final oido = await Servicios.voz.escuchar(
          maximo: const Duration(seconds: 10),
          basta: esDespertar,
        );
        if (!_corriendo) return;
        if (esDespertar(oido)) {
          _corriendo = false;
          _activo.value = false;
          final f = _alOir;
          _alOir = null;
          f?.call();
          return;
        }
        // "No te escuché" es normal (silencio). Otro problema (sin permiso,
        // sin reconocimiento) se reintenta poco y luego se deja de escuchar.
        final problema = Servicios.voz.problema;
        if (oido == null &&
            problema != null &&
            problema != explicarProblema('error_no_match')) {
          fallas++;
          debugPrint('NANA «Oye NANA»: $problema ($fallas)');
          if (fallas >= 3) return;
          await Future<void>.delayed(Duration(seconds: 2 * fallas));
        } else {
          fallas = 0;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    } finally {
      _corriendo = false;
      _activo.value = false;
    }
  }

  @override
  Future<void> parar() async {
    _alOir = null;
    if (!_corriendo) return;
    _corriendo = false;
    _activo.value = false;
    await Servicios.voz.dejarDeEscuchar();
  }
}

// Para saber si la pantalla que espera «Oye NANA» sigue hasta arriba
// (va en navigatorObservers de MaterialApp).
final rutasNana = RouteObserver<ModalRoute<void>>();
