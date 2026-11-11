import 'package:flutter/material.dart';

import '../models/actividad.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/mascota_nana.dart';

// Arma "el día" a partir de lo que hay en Firestore. Son funciones puras
// para poder probarlas sin pantallas.

// Las rutinas que tocan ese día, en la forma que usa diaDelAdulto.
List<(TimeOfDay, String, TipoActividad)> rutinasDeHoy(
  List<Rutina> rutinas,
  DateTime hoy,
) => [
  for (final r in rutinas)
    if (r.tocaEl(hoy)) (r.hora, r.titulo, r.tipo),
];

// Comidas y actividad física de ejemplo (las pruebas las usan por defecto).
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

bool _tomada(Medicamento m, List<Registro> hoy) =>
    hoy.any((r) => r.tipo == TipoActividad.medicina && r.idMedicamento == m.id);

List<Actividad> diaDelAdulto({
  required List<Medicamento> meds,
  required List<Registro> hoy,
  List<(TimeOfDay, String, TipoActividad)> otras = rutinasDelDia,
  DateTime? ahora,
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
          horaExacta: m.hora,
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
          horaExacta: hora,
        ),
      ),
  ]..sort((a, b) => _minutos(a.$1).compareTo(_minutos(b.$1)));

  final dia = [for (final (_, a) in filas) a];
  // Lo primero que falta es lo que "toca ahora". Una comida o actividad que
  // ya pasó hace más de 2 horas no se pide (en la tarde no se pregunta por el
  // desayuno); una medicina sí, hasta que se confirme.
  final minutoActual = ahora == null ? null : ahora.hour * 60 + ahora.minute;
  bool yaSePaso(Actividad a) =>
      minutoActual != null &&
      a.tipo != TipoActividad.medicina &&
      a.horaExacta != null &&
      _minutos(a.horaExacta!) + vencidaDespuesMin < minutoActual;
  final i = dia.indexWhere(
    (a) => a.estado == EstadoActividad.pendiente && !yaSePaso(a),
  );
  if (i != -1) dia[i] = dia[i].conEstado(EstadoActividad.ahora);
  return dia;
}

// Después de cuántos minutos una comida o actividad ya no "toca".
const vencidaDespuesMin = 120;

// Lo que muestra la tarjeta grande del inicio del adulto.
enum QueToca { actividad, animo, siguiente, listo }

// Cuánto antes de su hora una actividad ya se muestra como "toca ahora".
const avisoAntesMin = 15;

// En orden: lo que ya toca, luego el ánimo (una vez al día), luego lo que sigue.
(QueToca, Actividad?) queToca({
  required List<Actividad> dia,
  required int? animoHoy,
  required DateTime ahora,
}) {
  final siguiente = dia
      .where((a) => a.estado == EstadoActividad.ahora)
      .firstOrNull;
  final minutoActual = ahora.hour * 60 + ahora.minute;
  final yaToca =
      siguiente != null &&
      (siguiente.horaExacta == null ||
          _minutos(siguiente.horaExacta!) - minutoActual <= avisoAntesMin);
  if (yaToca) return (QueToca.actividad, siguiente);
  if (animoHoy == null) return (QueToca.animo, null);
  if (siguiente != null) return (QueToca.siguiente, siguiente);
  return (QueToca.listo, null);
}

// Cómo se cuenta un registro en la línea del cuidador y en el detalle del día.
String queHizo(Registro r) => switch (r.tipo) {
  TipoActividad.medicina => 'Tomó ${r.titulo}',
  TipoActividad.comida => '${r.titulo}: listo',
  TipoActividad.ejercicio => '${r.titulo}: hecho',
  TipoActividad.animo => 'Ánimo: ${r.titulo}',
  TipoActividad.mensaje => 'Dijo: "${r.titulo}"',
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
      if (!_tomada(m, hoy) && minutoActual > _minutos(m.hora) + m.ventanaMin) m,
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
          titulo: queHizo(r),
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

// "Sin noticias": hace más de [horas] que no se anota nada. Si nunca se ha
// anotado nada (recién dado de alta) no se avisa.
bool sinNoticias({
  required DateTime? ultima,
  required DateTime ahora,
  required int horas,
}) => ultima != null && ahora.difference(ultima) >= Duration(hours: horas);

// Cara de NANA en el inicio del adulto: contenta si ya hizo todo, atenta si
// algo ya toca (aunque sea de noche), dormida de 10 pm a 6 am y normal lo demás.
EstadoNana estadoNana({
  required List<Actividad> dia,
  required QueToca que,
  required DateTime ahora,
}) {
  if (dia.isNotEmpty && dia.every((a) => a.estado == EstadoActividad.hecha)) {
    return EstadoNana.contenta;
  }
  if (que == QueToca.actividad) return EstadoNana.atenta;
  if (ahora.hour >= 22 || ahora.hour < 6) return EstadoNana.dormida;
  return EstadoNana.normal;
}

String describirNana(EstadoNana e) => switch (e) {
  EstadoNana.contenta => 'NANA está contenta: hiciste todo lo de hoy',
  EstadoNana.atenta => 'NANA está atenta: algo ya te toca',
  EstadoNana.dormida => 'NANA está dormida',
  EstadoNana.normal => 'NANA',
};

// Lo que NANA dice en voz alta del inicio y cuando le preguntan "¿qué sigue?".
String textoDelDia({
  required String saludo,
  required List<Actividad> dia,
  required int? animoHoy,
  required DateTime ahora,
}) {
  final hechas = dia.where((a) => a.estado == EstadoActividad.hecha).length;
  final (que, a) = queToca(dia: dia, animoHoy: animoHoy, ahora: ahora);
  final cuenta = dia.isEmpty ? '' : ' Hoy llevas $hechas de ${dia.length}.';
  final ahoraToca = switch (que) {
    QueToca.actividad when a!.tipo == TipoActividad.medicina =>
      'Ahora te toca tu ${a.titulo}.',
    QueToca.actividad => 'Ahora te toca: ${a!.titulo}.',
    QueToca.animo => '¿Cómo te sientes hoy?',
    QueToca.siguiente => 'Lo que sigue: ${a!.titulo}, a las ${a.hora}.',
    QueToca.listo => 'Ya hiciste todo lo de hoy. ¡Muy bien!',
  };
  return '$saludo.$cuenta $ahoraToca';
}
