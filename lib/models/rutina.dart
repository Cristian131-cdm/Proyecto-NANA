import 'package:flutter/material.dart';

import 'actividad.dart';
import 'medicamento.dart';

// Una comida o actividad física que se repite ciertos días (RUTINA en el ER).
class Rutina {
  final String? id; // null mientras no se ha guardado
  final String titulo;
  final TipoActividad tipo; // comida o ejercicio
  final TimeOfDay hora;
  final Set<int> dias; // 0 = lunes ... 6 = domingo

  const Rutina({
    this.id,
    required this.titulo,
    required this.tipo,
    required this.hora,
    required this.dias,
  });

  bool tocaEl(DateTime fecha) => dias.contains(fecha.weekday - 1);

  Rutina conId(String nuevo) =>
      Rutina(id: nuevo, titulo: titulo, tipo: tipo, hora: hora, dias: dias);

  Map<String, dynamic> aMapa() => {
    'titulo': titulo,
    'tipo': tipo.name,
    'hora':
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
    'dias': (dias.toList()..sort()),
  };

  static Rutina deMapa(String id, Map<String, dynamic> m) => Rutina(
    id: id,
    titulo: m['titulo'] ?? '',
    tipo: TipoActividad.values.asNameMap()[m['tipo']] ?? TipoActividad.comida,
    hora: Medicamento.leerHora(m['hora'] ?? '08:00'),
    dias: {
      for (final d in (m['dias'] as List? ?? const [])) (d as num).toInt(),
    },
  );
}
