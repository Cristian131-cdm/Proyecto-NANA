import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/dia.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/registro.dart';
import 'package:nana_app/widgets/mascota_nana.dart';

const _losartan = Medicamento(
  id: 'losartan',
  nombre: 'Losartán',
  dosis: '50 mg',
  hora: TimeOfDay(hour: 8, minute: 0),
  ventanaMin: 30,
);

Registro _hizo(TipoActividad tipo, String titulo) => Registro(
  tipo: tipo,
  titulo: titulo,
  idMedicamento: tipo == TipoActividad.medicina ? 'losartan' : null,
  fecha: DateTime(2026, 11, 4, 8),
  registradoPor: 'rosa-cel',
);

// Solo el Losartán, sin comidas ni caminata, para que la prueba se lea fácil.
List<Actividad> _dia(List<Registro> hoy) =>
    diaDelAdulto(meds: const [_losartan], hoy: hoy, otras: const []);

DateTime _a(int hora, [int minuto = 0]) => DateTime(2026, 11, 4, hora, minuto);

void main() {
  test('Día vacío y sin ánimo: pregunta cómo se siente', () {
    final (que, a) = queToca(dia: const [], animoHoy: null, ahora: _a(9));
    expect(que, QueToca.animo);
    expect(a, isNull);
  });

  test('Todo hecho y ánimo dado: todo listo', () {
    final dia = _dia([_hizo(TipoActividad.medicina, 'Losartán 50 mg')]);
    final (que, _) = queToca(dia: dia, animoHoy: 3, ahora: _a(9));
    expect(que, QueToca.listo);
  });

  test('La medicina vencida va antes que el ánimo', () {
    final (que, a) = queToca(dia: _dia(const []), animoHoy: null, ahora: _a(9));
    expect(que, QueToca.actividad);
    expect(a!.titulo, 'Losartán 50 mg');
  });

  test('Faltan 10 minutos: ya se muestra', () {
    final (que, _) = queToca(
      dia: _dia(const []),
      animoHoy: 2,
      ahora: _a(7, 50),
    );
    expect(que, QueToca.actividad);
  });

  test('Faltan 2 horas: primero el ánimo, luego "lo que sigue"', () {
    expect(
      queToca(dia: _dia(const []), animoHoy: null, ahora: _a(6)).$1,
      QueToca.animo,
    );
    final (que, a) = queToca(dia: _dia(const []), animoHoy: 4, ahora: _a(6));
    expect(que, QueToca.siguiente);
    expect(a!.hora, '8:00');
  });

  test('Pasada la medianoche no cree que ya toca lo de las 8', () {
    final (que, _) = queToca(dia: _dia(const []), animoHoy: 1, ahora: _a(0, 5));
    expect(que, QueToca.siguiente);
  });

  test('Una actividad sin hora exacta se muestra de una vez', () {
    const suelta = Actividad(
      hora: '',
      titulo: 'Tomar agua',
      detalle: '',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.ahora,
    );
    final (que, _) = queToca(dia: const [suelta], animoHoy: 1, ahora: _a(6));
    expect(que, QueToca.actividad);
  });

  test('En la tarde ya no se pide el desayuno, pero la medicina sí', () {
    final dia = diaDelAdulto(
      meds: const [_losartan],
      hoy: const [],
      otras: const [
        (TimeOfDay(hour: 7, minute: 30), 'Desayuno', TipoActividad.comida),
        (TimeOfDay(hour: 14, minute: 0), 'Comida', TipoActividad.comida),
      ],
      ahora: DateTime(2026, 11, 7, 13, 50),
    );
    final ahora = dia.firstWhere((a) => a.estado == EstadoActividad.ahora);
    expect(ahora.titulo, startsWith('Losartán'));
  });

  test('Con la medicina tomada, en la tarde toca la comida', () {
    final dia = diaDelAdulto(
      meds: const [_losartan],
      hoy: [
        Registro(
          tipo: TipoActividad.medicina,
          titulo: 'Losartán 50 mg',
          idMedicamento: _losartan.id,
          fecha: DateTime(2026, 11, 7, 8, 5),
          registradoPor: 'rosa',
        ),
      ],
      otras: const [
        (TimeOfDay(hour: 7, minute: 30), 'Desayuno', TipoActividad.comida),
        (TimeOfDay(hour: 14, minute: 0), 'Comida', TipoActividad.comida),
      ],
      ahora: DateTime(2026, 11, 7, 13, 50),
    );
    final ahora = dia.firstWhere((a) => a.estado == EstadoActividad.ahora);
    expect(ahora.titulo, 'Comida');
  });

  test('La cara de NANA sigue al día', () {
    const pendiente = Actividad(
      hora: '8:00',
      titulo: 'Losartán',
      detalle: '',
      tipo: TipoActividad.medicina,
      estado: EstadoActividad.ahora,
    );
    final hecha = pendiente.conEstado(EstadoActividad.hecha);
    final tarde = DateTime(2026, 11, 9, 15);
    final noche = DateTime(2026, 11, 9, 23);

    expect(
      estadoNana(dia: [hecha], que: QueToca.listo, ahora: noche),
      EstadoNana.contenta,
    );
    expect(
      estadoNana(dia: [pendiente], que: QueToca.actividad, ahora: noche),
      EstadoNana.atenta,
    );
    expect(
      estadoNana(dia: [pendiente], que: QueToca.siguiente, ahora: noche),
      EstadoNana.dormida,
    );
    expect(
      estadoNana(dia: [pendiente], que: QueToca.siguiente, ahora: tarde),
      EstadoNana.normal,
    );
  });
}
