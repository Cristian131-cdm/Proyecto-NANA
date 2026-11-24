import 'package:flutter/foundation.dart';

import '../models/actividad.dart';
import 'agente.dart';
import 'platica.dart';
import 'servicios.dart';
import 'voz.dart';

/// Una plática de la persona mayor con NANA (la pantalla «Platicando con
/// NANA»). Decide quién contesta cada frase:
///
/// 1. Las reglas de la app (`respuestaAdulto`): ayuda, pregunta médica,
///    familia, la hora… Al instante y sin red. Lo crítico nunca espera al
///    agente.
/// 2. Lo demás (plática, lo que no entiende) se lo pregunta al agente de la
///    laptop, si hay uno configurado. Si no contesta a tiempo, la respuesta
///    fija de siempre.
///
/// Si el agente propone anotar algo («¿Anoto que ya te tomaste…?»), solo se
/// anota cuando la siguiente frase es un sí.
class ConversacionAdulto {
  final String nombre;
  final String Function() queSigue;
  final List<Actividad> Function() dia;
  final void Function(Actividad) anotar;

  final List<Map<String, String>> _historial = [];
  Actividad? _porAnotar;

  ConversacionAdulto({
    required this.nombre,
    required this.queSigue,
    required this.dia,
    required this.anotar,
  });

  Future<RespuestaPlatica> responder(String oido) async {
    final propuesta = _porAnotar;
    _porAnotar = null;
    if (propuesta != null) {
      switch (entender(oido, respuestasRecordatorio)) {
        case RespuestaRecordatorio.si:
          anotar(propuesta);
          return const RespuestaPlatica('Listo, ya lo anoté.');
        case RespuestaRecordatorio.alRato:
          return const RespuestaPlatica('Está bien, no lo anoto.');
        case null:
          break; // Cambió de tema: se sigue normal.
      }
    }
    final fija = respuestaAdulto(
      oido,
      nombre: nombre,
      queSigue: queSigue,
      ahora: Servicios.reloj(),
    );
    final agente = Servicios.agente;
    if (fija.fija || !agente.disponible) return fija;
    final hoy = dia();
    final r = await agente.preguntar(
      texto: oido,
      nombre: nombre,
      dia: diaParaAgente(hoy),
      historial: List.of(_historial),
    );
    // Solo en la versión de pruebas: qué dijo y qué contestó el agente.
    if (kDebugMode) {
      debugPrint(
        'NANA agente: «$oido» → «${r?.texto ?? '(sin agente)'}» '
        '${r?.etiqueta ?? ''} ${r?.proveedor ?? ''}',
      );
    }
    if (r == null) return fija;
    _historial
      ..add({'role': 'user', 'content': oido})
      ..add({'role': 'assistant', 'content': r.texto});
    if (_historial.length > 6) {
      _historial.removeRange(0, _historial.length - 6);
    }
    if (r.propuesta case PropuestaAgente(tipo: 'registro', :final id)) {
      _porAnotar = actividadPropuesta(hoy, id);
    }
    return respuestaDelAgente(r);
  }
}
