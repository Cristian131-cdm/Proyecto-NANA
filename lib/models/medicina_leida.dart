import 'package:flutter/material.dart';

import 'medicamento.dart';

// Una medicina que NANA leyó de la receta (agente/nana_agente/receta.py).
// No se guarda nada hasta que la familia dice «Sí, guardar» en
// «¿Está bien así?» (screens/leer_receta.dart).
class MedicinaLeida {
  final String nombre;
  final String dosis; // "50", "0.5"
  final String unidad; // mg, ml, tabletas…
  final List<TimeOfDay> horas;
  final int dias; // 0 = la receta no lo dice
  // Lo que conviene revisar ("la receta no dice la hora").
  final List<String> dudas;

  const MedicinaLeida({
    required this.nombre,
    required this.dosis,
    required this.unidad,
    required this.horas,
    this.dias = 0,
    this.dudas = const [],
  });

  MedicinaLeida copyWith({
    String? nombre,
    String? dosis,
    String? unidad,
    List<TimeOfDay>? horas,
  }) => MedicinaLeida(
    nombre: nombre ?? this.nombre,
    dosis: dosis ?? this.dosis,
    unidad: unidad ?? this.unidad,
    horas: horas ?? this.horas,
    dias: dias,
    dudas: dudas,
  );

  // Lo que manda el agente; null si algo no cuadra (se descarta).
  static MedicinaLeida? deJson(Object? j) {
    if (j is! Map) return null;
    final nombre = '${j['nombre'] ?? ''}'.trim();
    final dosis = '${j['dosis'] ?? ''}'.trim();
    final horas = <TimeOfDay>[
      for (final h in (j['horas'] as List? ?? const []))
        if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch('$h'))
          Medicamento.leerHora('$h'),
    ];
    if (nombre.isEmpty || dosis.isEmpty || horas.isEmpty) return null;
    return MedicinaLeida(
      nombre: nombre,
      dosis: dosis,
      unidad: '${j['unidad'] ?? 'mg'}',
      horas: horas,
      dias: (j['dias'] as num?)?.toInt() ?? 0,
      dudas: [for (final d in (j['dudas'] as List? ?? const [])) '$d'],
    );
  }

  // Una medicina de NANA por cada hora (así funciona la alarma de cada toma).
  List<Medicamento> comoMedicamentos({int ventanaMin = 30}) => [
    for (final h in horas)
      Medicamento(
        nombre: nombre,
        dosis: '$dosis $unidad',
        hora: h,
        ventanaMin: ventanaMin,
      ),
  ];
}
