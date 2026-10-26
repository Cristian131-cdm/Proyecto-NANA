import 'package:flutter/material.dart';

import '../models/actividad.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';

// Arma "el día" a partir de lo que hay en Firestore. Son funciones puras
// para poder probarlas sin pantallas.

// Comidas y actividad física fijas mientras las rutinas no estén en Firestore.
const rutinasDelDia = [
  (TimeOfDay(hour: 7, minute: 30), 'Desayuno', TipoActividad.comida),
  (TimeOfDay(hour: 14, minute: 0), 'Comida', TipoActividad.comida),
  (TimeOfDay(hour: 18, minute: 0), 'Caminar 15 min', TipoActividad.ejercicio),
];

// 8:00, 2:00 pm — como ya se escribía en la app
String horaCorta(TimeOfDay t) {
  final m = t.minute.toString().padLeft(2, '0');
  if (t.hour < 12) return '${t.hour}:$m';
  final h = t.hour == 12 ? 12 : t.hour - 12;
  return '$h:$m pm';
}

int _minutos(TimeOfDay t) => t.hour * 60 + t.minute;

bool _tomada(Medicamento m, List<Registro> hoy) => hoy.any(
  (r) => r.tipo == TipoActividad.medicina && r.idMedicamento == m.id,
);

List<Actividad> diaDelAdulto({
  required List<Medicamento> meds,
  required List<Registro> hoy,
  List<(TimeOfDay, String, TipoActividad)> otras = rutinasDelDia,
}) {
  final filas = <(TimeOfDay, Actividad)>[
    for (final m in meds)
      (
        m.hora,
        Actividad(
          hora: horaCorta(m.hora),
          titulo: '${m.nombre} ${m.dosis}',
          detalle: 'Tu medicina',
          tipo: TipoActividad.medicina,
          estado: _tomada(m, hoy)
              ? EstadoActividad.hecha
              : EstadoActividad.pendiente,
          idMedicamento: m.id,
        ),
      ),
    for (final (hora, titulo, tipo) in otras)
      (
        hora,
        Actividad(
          hora: horaCorta(hora),
          titulo: titulo,
          detalle: tipo == TipoActividad.comida ? 'Cuando comas' : 'Un ratito',
          tipo: tipo,
          estado: hoy.any((r) => r.tipo == tipo && r.titulo == titulo)
              ? EstadoActividad.hecha
              : EstadoActividad.pendiente,
        ),
      ),
  ]..sort((a, b) => _minutos(a.$1).compareTo(_minutos(b.$1)));

  final dia = [for (final (_, a) in filas) a];
  // Lo primero que falta es lo que "toca ahora".
  final i = dia.indexWhere((a) => a.estado == EstadoActividad.pendiente);
  if (i != -1) dia[i] = dia[i].conEstado(EstadoActividad.ahora);
  return dia;
}

String _queHizo(Registro r) => switch (r.tipo) {
  TipoActividad.medicina => 'Tomó ${r.titulo}',
  TipoActividad.comida => '${r.titulo}: listo',
  TipoActividad.ejercicio => '${r.titulo}: hecho',
  TipoActividad.animo => 'Ánimo: ${r.titulo}',
};

// Medicinas que ya pasaron su hora más la ventana y nadie confirmó.
List<Medicamento> sinConfirmar({
  required List<Medicamento> meds,
  required List<Registro> hoy,
  required DateTime ahora,
}) {
  final minutoActual = ahora.hour * 60 + ahora.minute;
  return [
    for (final m in meds)
      if (!_tomada(m, hoy) && minutoActual > _minutos(m.hora) + m.ventanaMin)
        m,
  ];
}

List<Actividad> lineaDelCuidador({
  required List<Medicamento> meds,
  required List<Registro> hoy,
  required DateTime ahora,
}) {
  final vencidas = sinConfirmar(meds: meds, hoy: hoy, ahora: ahora);
  final filas = <(int, Actividad)>[
    for (final r in hoy)
      (
        r.fecha.hour * 60 + r.fecha.minute,
        Actividad(
          hora: horaCorta(TimeOfDay.fromDateTime(r.fecha)),
          titulo: _queHizo(r),
          detalle: '',
          tipo: r.tipo,
          estado: EstadoActividad.hecha,
        ),
      ),
    for (final m in meds)
      if (!_tomada(m, hoy))
        (
          _minutos(m.hora),
          Actividad(
            hora: horaCorta(m.hora),
            titulo: vencidas.contains(m)
                ? '${m.nombre} sin confirmar'
                : '${m.nombre} ${m.dosis}',
            detalle: '',
            tipo: TipoActividad.medicina,
            estado: vencidas.contains(m)
                ? EstadoActividad.sinConfirmar
                : EstadoActividad.pendiente,
            idMedicamento: m.id,
          ),
        ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, a) in filas) a];
}
