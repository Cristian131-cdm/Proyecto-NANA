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

// 8:00 am, 2:00 pm, 12:00 pm (mediodía), 12:00 am (medianoche). Antes las
// de la mañana salían sin «am» y la medianoche como «0:00»: no se sabía si
// «8:00» era de la mañana o de la noche (Cris, 2026-11-25).
String horaCorta(TimeOfDay t) {
  final m = t.minute.toString().padLeft(2, '0');
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
}

// Las tomas de una misma medicina (mismo nombre, dosis y último día). En la
// lista del encargado se ven en UNA tarjeta: «Loratadina · cada 8 horas» con
// sus 3 horas, en vez de 3 tarjetas que parecían repetidas (Cris, 2026-11-25).
class GrupoMedicina {
  final String nombre;
  final String dosis;
  final List<Medicamento> tomas; // ordenadas por hora
  const GrupoMedicina(this.nombre, this.dosis, this.tomas);

  DateTime? get hasta => tomas.first.hasta;

  // «Una vez al día», «Cada 8 horas» o «3 veces al día» si no van parejas.
  String get frecuencia {
    final n = tomas.length;
    if (n == 1) return 'Una vez al día';
    if (24 % n == 0) {
      final cada = 24 ~/ n;
      int min(Medicamento m) => m.hora.hour * 60 + m.hora.minute;
      final parejas = [
        for (var i = 1; i < n; i++) min(tomas[i]) - min(tomas[i - 1]),
      ].every((d) => d == cada * 60);
      if (parejas) return 'Cada $cada horas';
    }
    return '$n veces al día';
  }
}

List<GrupoMedicina> agruparMedicinas(List<Medicamento> meds) {
  int min(Medicamento m) => m.hora.hour * 60 + m.hora.minute;
  final grupos = <String, List<Medicamento>>{};
  for (final m in meds) {
    final h = m.hasta;
    final clave = [
      m.nombre.trim().toLowerCase(),
      m.dosis.trim().toLowerCase(),
      h == null ? '' : '${h.year}-${h.month}-${h.day}',
    ].join('|');
    grupos.putIfAbsent(clave, () => []).add(m);
  }
  return [
    for (final tomas in grupos.values)
      GrupoMedicina(
        tomas.first.nombre,
        tomas.first.dosis,
        [...tomas]..sort((a, b) => min(a).compareTo(min(b))),
      ),
  ]..sort((a, b) => min(a.tomas.first).compareTo(min(b.tomas.first)));
}

// «martes 2 dic»
String diaCorto(DateTime d) {
  const dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
}

// La hora con que empieza el formulario: la de ahora, redondeada a los
// siguientes 5 minutos (6:42 pm → 6:45 pm).
TimeOfDay horaSugerida(DateTime ahora) {
  final total = ((ahora.hour * 60 + ahora.minute + 4) ~/ 5) * 5;
  return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
}

// La misma hora en la mañana (am) o en la tarde/noche (pm): 8:00 → 20:00.
TimeOfDay conMitad(TimeOfDay t, {required bool pm}) =>
    TimeOfDay(hour: t.hour % 12 + (pm ? 12 : 0), minute: t.minute);

// «Cada 8 horas» empezando a las 8:00 am → 8:00 am, 4:00 pm, 12:00 am.
// [cadaHoras] debe dividir 24 (24, 12, 8, 6); si no, solo la primera toma.
List<TimeOfDay> horasPorFrecuencia(TimeOfDay primera, int cadaHoras) {
  if (cadaHoras <= 0 || cadaHoras >= 24 || 24 % cadaHoras != 0) {
    return [primera];
  }
  return [
    for (var i = 0; i < 24 ~/ cadaHoras; i++)
      TimeOfDay(
        hour: (primera.hour + i * cadaHoras) % 24,
        minute: primera.minute,
      ),
  ];
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
  final fecha = ahora ?? DateTime.now();
  final filas = <(TimeOfDay, Actividad)>[
    for (final m in meds.where((m) => m.tocaEl(fecha)))
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
      if (m.tocaEl(ahora) &&
          !_tomada(m, hoy) &&
          minutoActual > _minutos(m.hora) + m.ventanaMin)
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
          titulo: queHizo(r),
          detalle: '',
          tipo: r.tipo,
          estado: EstadoActividad.hecha,
        ),
      ),
    for (final m in meds)
      if (m.tocaEl(ahora) && !_tomada(m, hoy))
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
  EstadoNana.pensando => 'NANA está pensando',
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

// Lo que NANA lee en "Todo mi día": cada cosa con su hora y cómo va.
String textoMiDia(List<Actividad> dia) {
  if (dia.isEmpty) return 'Hoy no tienes nada anotado.';
  final hechas = dia.where((a) => a.estado == EstadoActividad.hecha).length;
  final b = StringBuffer('Tu día. Llevas $hechas de ${dia.length}. ');
  for (final a in dia) {
    final como = switch (a.estado) {
      EstadoActividad.hecha => 'listo',
      EstadoActividad.ahora => 'toca ahora',
      EstadoActividad.pendiente => 'más tarde',
      EstadoActividad.sinConfirmar => 'falta confirmar',
    };
    b.write('${a.hora}, ${a.titulo}: $como. ');
  }
  return b.toString().trim();
}
