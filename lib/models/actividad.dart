import 'package:flutter/material.dart';

import '../core/tema.dart';

enum TipoActividad { medicina, comida, ejercicio, animo }

enum EstadoActividad { hecha, ahora, pendiente, sinConfirmar }

extension TipoActividadVisual on TipoActividad {
  IconData get icono => switch (this) {
        TipoActividad.medicina => Icons.medication,
        TipoActividad.comida => Icons.restaurant,
        TipoActividad.ejercicio => Icons.directions_walk,
        TipoActividad.animo => Icons.mood,
      };
}

extension EstadoActividadVisual on EstadoActividad {
  Color get color => switch (this) {
        EstadoActividad.hecha => ColoresNana.ok,
        EstadoActividad.ahora => ColoresNana.morado,
        EstadoActividad.pendiente => const Color(0xFF8A82A3),
        EstadoActividad.sinConfirmar => ColoresNana.alerta,
      };
}

class Actividad {
  final String hora;
  final String titulo;
  final String detalle;
  final TipoActividad tipo;
  final EstadoActividad estado;

  const Actividad({
    required this.hora,
    required this.titulo,
    required this.detalle,
    required this.tipo,
    required this.estado,
  });

  Actividad conEstado(EstadoActividad nuevo) => Actividad(
        hora: hora,
        titulo: titulo,
        detalle: detalle,
        tipo: tipo,
        estado: nuevo,
      );
}
