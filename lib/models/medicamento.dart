import 'package:flutter/material.dart';

class Medicamento {
  final String? id; // null mientras no se ha guardado
  final String nombre;
  final String dosis;
  final TimeOfDay hora;
  final int ventanaMin; // minutos que NANA espera antes de alertar
  // Último día del tratamiento (inclusive, solo la fecha). null = siempre.
  final DateTime? hasta;
  // Primer día que cuenta esta toma (solo la fecha). Si se da de alta a las
  // 8:45 pm «cada 12 h», la de 8:45 am empieza mañana. null = desde siempre.
  final DateTime? desde;

  const Medicamento({
    this.id,
    required this.nombre,
    required this.dosis,
    required this.hora,
    required this.ventanaMin,
    this.hasta,
    this.desde,
  });

  Medicamento conId(String nuevo) => Medicamento(
    id: nuevo,
    nombre: nombre,
    dosis: dosis,
    hora: hora,
    ventanaMin: ventanaMin,
    hasta: hasta,
    desde: desde,
  );

  // ¿Todavía se toma ese día? El último día (hasta) sí cuenta.
  bool vigente(DateTime dia) {
    final fin = hasta;
    if (fin == null) return true;
    final d = DateTime(dia.year, dia.month, dia.day);
    return !d.isAfter(DateTime(fin.year, fin.month, fin.day));
  }

  // ¿Ya empezó ese día?
  bool empezo(DateTime dia) {
    final inicio = desde;
    if (inicio == null) return true;
    final d = DateTime(dia.year, dia.month, dia.day);
    return !d.isBefore(DateTime(inicio.year, inicio.month, inicio.day));
  }

  // ¿Le toca ese día? (ya empezó y todavía no termina)
  bool tocaEl(DateTime dia) => empezo(dia) && vigente(dia);

  // El primer día de una toma a [hora] dada de alta en [ahora]: hoy si esa
  // hora todavía no pasa; si ya pasó, mañana.
  static DateTime primerDia(TimeOfDay hora, DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final yaPaso =
        hora.hour * 60 + hora.minute <= ahora.hour * 60 + ahora.minute;
    return yaPaso ? DateTime(hoy.year, hoy.month, hoy.day + 1) : hoy;
  }

  // «Por 7 días» empezando [desde] → el último día es desde + 6.
  static DateTime ultimoDia(DateTime desde, int dias) =>
      DateTime(desde.year, desde.month, desde.day + dias - 1);

  // 'HH:mm', como se guarda en Firestore
  String get horaTexto =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  static TimeOfDay leerHora(String texto) {
    final [h, m] = texto.split(':');
    return TimeOfDay(hour: int.parse(h), minute: int.parse(m));
  }
}
