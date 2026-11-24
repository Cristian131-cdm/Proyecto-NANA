import 'package:flutter/material.dart';

import '../models/actividad.dart';
import '../models/registro.dart';
import '../widgets/caritas_animo.dart';
import 'dia.dart';
import 'platica.dart';
import 'semana.dart';

// Lo que se le manda al agente en «Pregúntale a NANA». La app ya CUENTA todo
// (qué medicina se marcó cada día, cuál no, totales por medicina): el modelo
// de 8B no sabe contar y se equivocaba. Él solo lo lee y lo dice en palabras.
//
// Solo sale de DatosEncargado: medicinas (nombre y hora, sin dosis), rutinas,
// registros, ánimo, frases y alertas. Nunca el expediente de salud,
// teléfonos ni apellidos: vale igual para principal, suplente y familiar.

String _hora(DateTime f) => horaCorta(TimeOfDay.fromDateTime(f));

String _nombreDia(DateTime f, DateTime hoy) =>
    '${nombresDias[f.weekday - 1]} ${f.day}'
    '${DateUtils.isSameDay(f, hoy) ? ' (hoy)' : ''}';

Map<String, Object?> resumenParaAgente(DatosEncargado d) {
  final dias = semana(
    meds: d.meds,
    rutinas: d.rutinas,
    registros: d.semana,
    hoy: d.ahora,
  )..sort((a, b) => a.fecha.compareTo(b.fecha));
  final nombreDe = {
    for (final m in d.meds)
      if (m.id != null) m.id!: m.nombre,
  };
  final minuto = d.ahora.hour * 60 + d.ahora.minute;

  var marcadas = 0;
  var sinMarcar = 0;
  final faltasPorMed = <String, List<String>>{
    for (final m in d.meds) m.nombre: [],
  };
  final diasMal = <String>[];
  final diasSinComer = <String>[];
  var diasConActividad = 0;

  final filas = <Map<String, Object?>>[];
  for (final dia in dias) {
    final nombre = _nombreDia(dia.fecha, d.ahora);
    final esHoy = DateUtils.isSameDay(dia.fecha, d.ahora);
    List<Registro> de(TipoActividad t) =>
        dia.registros.where((r) => r.tipo == t).toList();
    final meds = de(TipoActividad.medicina);
    final tomadas = {for (final r in meds) r.idMedicamento};
    // Hoy solo cuenta como «sin marcar» lo que ya pasó de su hora.
    final faltan = [
      for (final m in d.meds)
        if (!tomadas.contains(m.id) &&
            (!esHoy ||
                m.hora.hour * 60 + m.hora.minute + m.ventanaMin < minuto))
          m.nombre,
    ];
    final comidas = de(TipoActividad.comida);
    final actividad = de(TipoActividad.ejercicio);
    final animos = de(TipoActividad.animo);
    final dijo = de(TipoActividad.mensaje);

    marcadas += meds.length;
    sinMarcar += faltan.length;
    for (final f in faltan) {
      faltasPorMed[f]?.add(nombre);
    }
    if (dia.horaMal != null ||
        dijo.any((r) => r.titulo.toLowerCase().contains('mal'))) {
      diasMal.add(nombre);
    }
    if (comidas.isEmpty && !esHoy) diasSinComer.add(nombre);
    if (actividad.isNotEmpty) diasConActividad++;

    final animo = animos.isEmpty ? null : animos.last.valor;
    filas.add({
      'dia': nombre,
      'medicinas_marcadas': [
        for (final r in meds)
          '${nombreDe[r.idMedicamento] ?? r.titulo} a las ${_hora(r.fecha)}',
      ],
      'medicinas_sin_marcar': faltan,
      'comidas': [
        for (final r in comidas) '${r.titulo} a las ${_hora(r.fecha)}',
      ],
      'actividad': [for (final r in actividad) r.titulo],
      'animo': animo == null || animo >= CaritasAnimo.etiquetas.length
          ? null
          : CaritasAnimo.etiquetas[animo],
      'dijo': [for (final r in dijo) '${r.titulo} a las ${_hora(r.fecha)}'],
    });
  }

  return {
    'hoy': '${nombresDias[d.ahora.weekday - 1]} ${fechaLarga(d.ahora)}',
    'hora': _hora(d.ahora),
    'medicinas': [
      for (final m in d.meds) {'nombre': m.nombre, 'hora': horaCorta(m.hora)},
    ],
    'dias': filas,
    'alertas_sin_atender': d.alertas.length,
    'totales_7_dias': {
      'medicinas_marcadas': marcadas,
      'medicinas_sin_marcar': sinMarcar,
      'medicinas_que_tocaban': marcadas + sinMarcar,
      'dias_sin_marcar_por_medicina': faltasPorMed,
      'dias_que_dijo_sentirse_mal': diasMal,
      'dias_sin_comidas': diasSinComer,
      'dias_con_actividad': diasConActividad,
    },
  };
}
