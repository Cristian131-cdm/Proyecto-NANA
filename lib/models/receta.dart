// Lo que indicó un médico, tal cual lo capturó la familia (RECETA en el ER).
class Receta {
  final String? id;
  final String medico;
  final DateTime fecha;
  final String indicacion;

  const Receta({
    this.id,
    required this.medico,
    required this.fecha,
    required this.indicacion,
  });

  Receta conId(String nuevo) =>
      Receta(id: nuevo, medico: medico, fecha: fecha, indicacion: indicacion);
}

// Una cita médica próxima.
class Cita {
  final String? id;
  final String especialidad;
  final DateTime fecha; // día y hora
  final String lugar;

  const Cita({
    this.id,
    required this.especialidad,
    required this.fecha,
    required this.lugar,
  });

  Cita conId(String nuevo) =>
      Cita(id: nuevo, especialidad: especialidad, fecha: fecha, lugar: lugar);
}

const mesesCortos = [
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

// "2 oct"
String fechaCorta(DateTime f) => '${f.day} ${mesesCortos[f.month - 1]}';
