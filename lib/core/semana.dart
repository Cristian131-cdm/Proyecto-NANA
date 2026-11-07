import 'package:flutter/material.dart';

import '../models/actividad.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/caritas_animo.dart';
import 'dia.dart';

const nombresDias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

// Un día de la semana tal como se ve en la gráfica.
class DiaSemana {
  final DateTime fecha;
  final int tomas; // medicinas confirmadas ese día
  final int posibles; // medicinas que tocaban
  final int? animo; // índice de CaritasAnimo; null si no dijo
  final int movimiento; // actividades físicas hechas
  final int movimientoPosible;
  final DateTime? horaMal; // cuándo dijo que se sentía mal, si dijo

  const DiaSemana({
    required this.fecha,
    required this.tomas,
    required this.posibles,
    required this.animo,
    required this.movimiento,
    required this.movimientoPosible,
    this.horaMal,
  });

  String get letra =>
      const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][fecha.weekday - 1];
  String get nombre => nombresDias[fecha.weekday - 1];
  bool get completo => posibles > 0 && tomas >= posibles;
}

// Los últimos 7 días, de hace 6 días hasta hoy. Función pura para probarla.
// Usa las medicinas de hoy para todos los días: si una se dio de alta a media
// semana, los días anteriores salen como "faltó" (es una aproximación).
List<DiaSemana> semana({
  required List<Medicamento> meds,
  required List<Rutina> rutinas,
  required List<Registro> registros,
  required DateTime hoy,
}) {
  final inicio = DateUtils.dateOnly(hoy).subtract(const Duration(days: 6));
  return [
    for (var i = 0; i < 7; i++)
      _dia(DateUtils.addDaysToDate(inicio, i), hoy, meds, rutinas, [
        for (final r in registros)
          if (DateUtils.isSameDay(r.fecha, DateUtils.addDaysToDate(inicio, i)))
            r,
      ]),
  ];
}

DiaSemana _dia(
  DateTime fecha,
  DateTime ahora,
  List<Medicamento> meds,
  List<Rutina> rutinas,
  List<Registro> delDia,
) {
  final tomadas = {
    for (final r in delDia)
      if (r.tipo == TipoActividad.medicina && r.idMedicamento != null)
        r.idMedicamento,
  };
  final animos = delDia.where((r) => r.tipo == TipoActividad.animo).toList();
  final mal = animos.where((r) => (r.valor ?? 0) >= 3).toList();
  // Hoy solo cuenta lo que ya se hizo o lo que ya se pasó de su hora: el día
  // todavía no termina y no es "faltó".
  final esHoy = DateUtils.isSameDay(fecha, ahora);
  final minuto = ahora.hour * 60 + ahora.minute;
  bool yaPaso(TimeOfDay h, int margen) =>
      !esHoy || h.hour * 60 + h.minute + margen < minuto;
  final medsDelDia = meds
      .where((m) => tomadas.contains(m.id) || yaPaso(m.hora, m.ventanaMin))
      .toList();
  final ejercicio = rutinas
      .where((r) => r.tipo == TipoActividad.ejercicio && r.tocaEl(fecha))
      .toList();
  final hechos = {
    for (final r in delDia)
      if (r.tipo == TipoActividad.ejercicio) r.titulo,
  };
  return DiaSemana(
    fecha: fecha,
    tomas: meds.where((m) => tomadas.contains(m.id)).length,
    posibles: medsDelDia.length,
    animo: animos.isEmpty ? null : animos.last.valor,
    movimiento: ejercicio.where((r) => hechos.contains(r.titulo)).length,
    movimientoPosible: ejercicio
        .where((r) => hechos.contains(r.titulo) || yaPaso(r.hora, 60))
        .length,
    horaMal: mal.isEmpty ? null : mal.last.fecha,
  );
}

String rangoSemana(List<DiaSemana> dias) {
  final a = dias.first.fecha;
  final b = dias.last.fecha;
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return a.month == b.month
      ? 'Del ${a.day} al ${b.day} de ${meses[b.month - 1]}'
      : 'Del ${a.day} de ${meses[a.month - 1]} al ${b.day} de ${meses[b.month - 1]}';
}

// Texto que se comparte por WhatsApp, SMS, etc. Solo datos, sin consejos.
String resumenSemana(String adulto, List<DiaSemana> dias) {
  final total = dias.fold(0, (a, d) => a + d.tomas);
  final posibles = dias.fold(0, (a, d) => a + d.posibles);
  final faltas = [
    for (final d in dias)
      if (d.posibles > 0 && !d.completo) d.nombre,
  ];
  final animos = [
    for (final d in dias)
      if (d.animo != null)
        '${d.nombre} ${CaritasAnimo.etiquetas[d.animo!].toLowerCase()}',
  ];
  return [
    'Resumen de la semana de $adulto (NANA)',
    rangoSemana(dias),
    posibles == 0
        ? 'Medicinas: no tiene medicinas registradas'
        : 'Medicinas a tiempo: $total de $posibles'
              '${faltas.isEmpty ? '' : ' · faltó el ${faltas.join(' y el ')}'}',
    animos.isEmpty
        ? 'Cómo se sintió: no lo registró esta semana'
        : 'Cómo se sintió: ${animos.join(', ')}',
    'NANA solo registra, recuerda y alerta. No da recomendaciones médicas.',
  ].join('\n');
}

String horaDe(DateTime f) => horaCorta(TimeOfDay.fromDateTime(f));
