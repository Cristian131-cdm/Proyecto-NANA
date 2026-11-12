import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'clasificador.dart';

// Las señas que NANA puede aprender y lo que significa cada una. Las frases
// son las mismas de core/frases.dart, así que llegan a la familia igual que
// si se hubieran tocado. "sí" y "no" solo sirven para contestarle a NANA.
class SenaNana {
  final String id;
  final String frase;
  const SenaNana(this.id, this.frase);
}

const senaSi = 'si';
const senaNo = 'no';

const senasNana = [
  SenaNana(senaSi, 'Sí'),
  SenaNana(senaNo, 'No'),
  SenaNana('ayuda', 'Necesito ayuda'),
  SenaNana('dolor', 'Me duele algo'),
  SenaNana('mal', 'Me siento mal'),
  SenaNana('bien', 'Me siento bien'),
  SenaNana('medicina', 'Ya tomé mi medicina'),
  SenaNana('comi', 'Ya comí'),
  SenaNana('hambre', 'Tengo hambre'),
  SenaNana('familia', 'Quiero hablar con mi familia'),
];

String? fraseDeSena(String id) {
  for (final s in senasNana) {
    if (s.id == id) return s.frase;
  }
  return null;
}

// Dónde viven los ejemplos: los que vienen con la app (assets/senas.json,
// grabados por el equipo) más los que se graban en este celular. Solo son
// números (los puntos de la mano); nunca se guarda imagen ni video.
class AlmacenSenas {
  static const _clave = 'senas_ejemplos';
  static const rutaAsset = 'assets/senas/senas.json';

  List<EjemploSena> deLaApp = [];
  List<EjemploSena> deEsteCelular = [];

  List<EjemploSena> get todos => [...deLaApp, ...deEsteCelular];
  ClasificadorSenas get clasificador => ClasificadorSenas(todos);

  bool _cargado = false;

  // Lee los ejemplos una sola vez; después ya están en memoria.
  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      deLaApp = ejemplosDeJson(await rootBundle.loadString(rutaAsset));
    } catch (_) {
      deLaApp = []; // todavía no hay archivo: se empieza de cero
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      deEsteCelular = ejemplosDeJson(prefs.getString(_clave) ?? '');
    } catch (_) {
      deEsteCelular = [];
    }
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, ejemplosAJson(deEsteCelular));
  }

  // Se guarda también en espejo, para que la seña valga con las dos manos.
  Future<void> agregar(EjemploSena e) async {
    deEsteCelular
      ..add(e)
      ..add(EjemploSena(e.sena, espejoDe(e.mano)));
    await _guardar();
  }

  // Borra lo grabado aquí de una seña (lo que viene con la app no se toca).
  Future<void> borrar(String sena) async {
    deEsteCelular.removeWhere((e) => e.sena == sena);
    await _guardar();
  }

  // Para pasarlo al equipo y dejarlo como assets/senas/senas.json.
  String exportar() => ejemplosAJson(todos);
}
