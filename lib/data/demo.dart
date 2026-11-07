import 'package:flutter/material.dart';

import '../models/actividad.dart';
import '../models/receta.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/caritas_animo.dart';
import 'repositorio.dart';

// Llena a un adulto con datos de demostración: rutinas, una receta, dos citas
// y lo que "pasó" los 6 días anteriores (no toca el día de hoy, para que en la
// demo se vea en vivo lo que hace el adulto). No duplica lo que ya existe.
// Devuelve cuántas cosas agregó.
Future<int> cargarDemo(
  RepositorioNana repo,
  String folio,
  DateTime ahora,
) async {
  var agregadas = 0;
  final hoy = DateUtils.dateOnly(ahora);
  const diario = {0, 1, 2, 3, 4, 5, 6};

  final rutinas = await repo.rutinas(folio).first;
  final nuevas = [
    const Rutina(
      titulo: 'Desayuno',
      tipo: TipoActividad.comida,
      hora: TimeOfDay(hour: 8, minute: 30),
      dias: diario,
    ),
    const Rutina(
      titulo: 'Comida',
      tipo: TipoActividad.comida,
      hora: TimeOfDay(hour: 14, minute: 0),
      dias: diario,
    ),
    const Rutina(
      titulo: 'Caminar 15 min',
      tipo: TipoActividad.ejercicio,
      hora: TimeOfDay(hour: 18, minute: 0),
      dias: {0, 1, 2, 3, 4},
    ),
    const Rutina(
      titulo: 'Cena',
      tipo: TipoActividad.comida,
      hora: TimeOfDay(hour: 20, minute: 30),
      dias: diario,
    ),
  ];
  for (final r in nuevas) {
    if (rutinas.any((x) => x.titulo == r.titulo)) continue;
    await repo.guardarRutina(folio, r);
    agregadas++;
  }

  final recetas = await repo.recetas(folio).first;
  if (recetas.isEmpty) {
    await repo.guardarReceta(
      folio,
      Receta(
        medico: 'Dr. Pérez',
        fecha: hoy.subtract(const Duration(days: 30)),
        indicacion: 'Losartán 50 mg · 1 al día',
      ),
    );
    agregadas++;
  }

  final citas = await repo.citas(folio).first;
  if (citas.isEmpty) {
    for (final (dias, hora, especialidad, lugar) in [
      (4, 10, 'Cardiología', 'Clínica 25'),
      (12, 8, 'Análisis de sangre', 'Laboratorio del IMSS'),
    ]) {
      await repo.guardarCita(
        folio,
        Cita(
          especialidad: especialidad,
          fecha: hoy.add(Duration(days: dias, hours: hora)),
          lugar: lugar,
        ),
      );
      agregadas++;
    }
  }

  // La semana pasada: medicinas casi siempre a tiempo, un día se le pasó,
  // un día se sintió mal y caminó casi todos los días entre semana.
  final inicio = hoy.subtract(const Duration(days: 6));
  final previos = await repo.registrosDesde(folio, inicio).first;
  final yaHayDias = {
    for (final r in previos)
      if (r.fecha.isBefore(hoy)) DateUtils.dateOnly(r.fecha),
  };
  final meds = await repo.medicamentos(folio).first;
  const animos = [1, 0, 1, 2, 1, 3]; // índice de CaritasAnimo, de hace 6 a ayer
  for (var i = 0; i < 6; i++) {
    final dia = DateUtils.addDaysToDate(inicio, i);
    if (yaHayDias.contains(dia)) continue;
    DateTime a(int h, int m) => dia.add(Duration(hours: h, minutes: m));
    Registro registro(
      TipoActividad tipo,
      String titulo,
      DateTime fecha, {
      String? idMedicamento,
      int? valor,
    }) => Registro(
      tipo: tipo,
      titulo: titulo,
      idMedicamento: idMedicamento,
      valor: valor,
      fecha: fecha,
      registradoPor: 'demo',
    );

    // Hace 4 días se le pasó la medicina.
    if (i != 2) {
      for (final m in meds) {
        await repo.registrar(
          folio,
          registro(
            TipoActividad.medicina,
            '${m.nombre} ${m.dosis}',
            a(m.hora.hour, m.hora.minute + 5 + i),
            idMedicamento: m.id,
          ),
        );
      }
    }
    await repo.registrar(
      folio,
      registro(TipoActividad.comida, 'Desayuno', a(8, 40)),
    );
    await repo.registrar(
      folio,
      registro(
        TipoActividad.animo,
        CaritasAnimo.etiquetas[animos[i]],
        a(i == 5 ? 19 : 10, i == 5 ? 40 : 15),
        valor: animos[i],
      ),
    );
    if (dia.weekday <= 5 && i != 4) {
      await repo.registrar(
        folio,
        registro(TipoActividad.ejercicio, 'Caminar 15 min', a(18, 10)),
      );
    }
    agregadas++;
  }
  return agregadas;
}
