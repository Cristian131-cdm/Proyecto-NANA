import 'package:flutter/material.dart';

class Medicamento {
  final String? id; // null mientras no se ha guardado
  final String nombre;
  final String dosis;
  final TimeOfDay hora;
  final int ventanaMin; // minutos que NANA espera antes de alertar

  const Medicamento({
    this.id,
    required this.nombre,
    required this.dosis,
    required this.hora,
    required this.ventanaMin,
  });

  Medicamento conId(String nuevo) => Medicamento(
        id: nuevo,
        nombre: nombre,
        dosis: dosis,
        hora: hora,
        ventanaMin: ventanaMin,
      );

  // 'HH:mm', como se guarda en Firestore
  String get horaTexto =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  static TimeOfDay leerHora(String texto) {
    final [h, m] = texto.split(':');
    return TimeOfDay(hour: int.parse(h), minute: int.parse(m));
  }
}
