import 'package:flutter/foundation.dart';

import 'platica.dart';
import 'resumen_encargado.dart';
import 'servicios.dart';

/// «Pregúntale a NANA» de quien cuida. Igual que [ConversacionAdulto]:
///
/// 1. Lo que la app ya sabe contestar con datos exactos (`respuestaEncargado`):
///    despedida, pregunta médica, cómo va hoy, la semana, la pastilla, el
///    ánimo, alertas, qué sigue. Sin red.
/// 2. Lo demás («¿qué días no se marcó el Losartán?», «¿comió bien?») se lo
///    pregunta al agente con el RESUMEN que arma la app; solo lectura. Si no
///    contesta, la respuesta de siempre.
class ConversacionEncargado {
  final String folio;
  final String nombre;

  final List<Map<String, String>> _historial = [];

  ConversacionEncargado({required this.folio, required this.nombre});

  Future<RespuestaPlatica> responder(String oido) async {
    final datos = await cargarDatosEncargado(folio, nombre);
    final fija = respuestaEncargado(oido, datos);
    final agente = Servicios.agente;
    if (fija.fija || !agente.disponible) return fija;
    final r = await agente.preguntarEncargado(
      pregunta: oido,
      nombre: nombre,
      datos: resumenParaAgente(datos),
      historial: List.of(_historial),
    );
    // Solo en la versión de pruebas: para revisar en la terminal de
    // `flutter run` qué preguntó y qué contestó el agente.
    if (kDebugMode) {
      debugPrint(
        'NANA encargado: «$oido» → «${r?.texto ?? '(sin agente)'}» '
        '${r?.proveedor ?? ''}',
      );
    }
    if (r == null) return fija;
    _historial
      ..add({'role': 'user', 'content': oido})
      ..add({'role': 'assistant', 'content': r.texto});
    if (_historial.length > 6) {
      _historial.removeRange(0, _historial.length - 6);
    }
    return RespuestaPlatica(r.texto, fija: false);
  }
}
