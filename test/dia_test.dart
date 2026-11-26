import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nana_app/models/rutina.dart';

import 'package:nana_app/core/dia.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/registro.dart';

const _losartan = Medicamento(
  id: 'losartan',
  nombre: 'Losartán',
  dosis: '50 mg',
  hora: TimeOfDay(hour: 8, minute: 0),
  ventanaMin: 30,
);

Registro _tomo(DateTime cuando) => Registro(
  tipo: TipoActividad.medicina,
  titulo: 'Losartán 50 mg',
  idMedicamento: 'losartan',
  fecha: cuando,
  registradoPor: 'rosa-cel',
);

void main() {
  final hoy = DateTime(2026, 10, 26);

  test('Pasada la ventana sin confirmar, el cuidador lo ve en alerta', () {
    final linea = lineaDelCuidador(
      meds: [_losartan],
      hoy: const [],
      ahora: hoy.add(const Duration(hours: 8, minutes: 40)),
    );
    expect(linea.single.estado, EstadoActividad.sinConfirmar);
    expect(linea.single.titulo, 'Losartán sin confirmar');
  });

  test('Dentro de la ventana todavía no es alerta', () {
    final linea = lineaDelCuidador(
      meds: [_losartan],
      hoy: const [],
      ahora: hoy.add(const Duration(hours: 8, minutes: 30)),
    );
    expect(linea.single.estado, EstadoActividad.pendiente);
  });

  test('Si la tomó, el cuidador ve a qué hora', () {
    final linea = lineaDelCuidador(
      meds: [_losartan],
      hoy: [_tomo(hoy.add(const Duration(hours: 8, minutes: 5)))],
      ahora: hoy.add(const Duration(hours: 9)),
    );
    expect(linea.single.estado, EstadoActividad.hecha);
    expect(linea.single.titulo, 'Tomó Losartán 50 mg');
    expect(linea.single.hora, '8:05 am');
  });

  test('El día de Rosa va en orden y marca lo que toca ahora', () {
    final dia = diaDelAdulto(meds: [_losartan], hoy: const []);
    expect(dia.map((a) => a.titulo), [
      'Desayuno',
      'Losartán 50 mg',
      'Comida',
      'Caminar 15 min',
    ]);
    expect(dia.first.estado, EstadoActividad.ahora);
    expect(dia[1].estado, EstadoActividad.pendiente);
    expect(dia[2].hora, '2:00 pm');
  });

  test('Lo que ya anotó Rosa sale como hecho', () {
    final dia = diaDelAdulto(
      meds: [_losartan],
      hoy: [
        _tomo(hoy),
        Registro(
          tipo: TipoActividad.comida,
          titulo: 'Desayuno',
          fecha: hoy,
          registradoPor: 'rosa-cel',
        ),
      ],
    );
    expect(dia[0].estado, EstadoActividad.hecha);
    expect(dia[1].estado, EstadoActividad.hecha);
    expect(dia[2].estado, EstadoActividad.ahora);
  });

  test('Solo entran las rutinas que tocan ese día', () {
    const caminar = Rutina(
      titulo: 'Caminar',
      tipo: TipoActividad.ejercicio,
      hora: TimeOfDay(hour: 18, minute: 0),
      dias: {0, 1, 2, 3, 4}, // lunes a viernes
    );
    expect(rutinasDeHoy(const [caminar], DateTime(2026, 11, 6)).length, 1);
    expect(rutinasDeHoy(const [caminar], DateTime(2026, 11, 8)), isEmpty);
  });

  test('Sin noticias: avisa después de las horas elegidas', () {
    final ultima = DateTime(2026, 11, 8, 8);
    expect(
      sinNoticias(ultima: ultima, ahora: DateTime(2026, 11, 8, 19), horas: 12),
      isFalse,
    );
    expect(
      sinNoticias(ultima: ultima, ahora: DateTime(2026, 11, 8, 20), horas: 12),
      isTrue,
    );
    expect(
      sinNoticias(ultima: null, ahora: DateTime(2026, 11, 9), horas: 12),
      isFalse,
    );
  });

  test('La rutina se guarda y se lee igual', () {
    const r = Rutina(
      titulo: 'Cena',
      tipo: TipoActividad.comida,
      hora: TimeOfDay(hour: 20, minute: 30),
      dias: {6, 1},
    );
    final leida = Rutina.deMapa('x', r.aMapa());
    expect(leida.titulo, 'Cena');
    expect(leida.hora, const TimeOfDay(hour: 20, minute: 30));
    expect(leida.dias, {1, 6});
    expect(leida.tipo, TipoActividad.comida);
  });
}
