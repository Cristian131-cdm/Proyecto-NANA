import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/alarmas.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/screens/panel_adulto.dart';

class _AlarmasFalsas implements Alarmas {
  final programadas = <List<Medicamento>>[];

  @override
  String? get abiertaDesde => null;

  @override
  Future<void> iniciar(void Function(String) alTocar) async {}

  @override
  Future<void> programar(String nombreAdulto, List<Medicamento> meds) async =>
      programadas.add(meds);
}

const _losartan = Medicamento(
  id: 'losartan',
  nombre: 'Losartán',
  dosis: '50 mg',
  hora: TimeOfDay(hour: 8, minute: 0),
  ventanaMin: 30,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('La alarma dice la hora y la medicina', () {
    expect(
      textoAlarma('Rosa', _losartan),
      'Rosa, son las 8:00. Te toca tu Losartán de 50 mg.',
    );
  });

  test('Cada medicina tiene siempre el mismo número de alarma', () {
    expect(idNotificacion('abc'), idNotificacion('abc'));
    expect(idNotificacion('abc'), isNot(idNotificacion('abd')));
    for (final id in ['abc', 'Xk29fP0q1', '']) {
      expect(idNotificacion(id), inInclusiveRange(0, 0x7fffffff));
    }
  });

  testWidgets('Al abrir su día y al cambiar las medicinas se reprograman',
      (t) async {
    final alarmas = _AlarmasFalsas();
    Servicios.alarmas = alarmas;
    addTearDown(() => Servicios.alarmas = AlarmasLocales());
    final repo = RepositorioMemoria(sesion: 'rosa-cel');
    Servicios.repo = repo;

    await t.pumpWidget(const MaterialApp(home: PanelAdulto()));
    await t.pumpAndSettle();
    expect(alarmas.programadas.last.single.nombre, 'Losartán');

    await repo.guardarMedicamento(
      'rosa',
      const Medicamento(
        nombre: 'Metformina',
        dosis: '850 mg',
        hora: TimeOfDay(hour: 20, minute: 0),
        ventanaMin: 30,
      ),
    );
    await t.pumpAndSettle();
    expect(alarmas.programadas.last, hasLength(2));
  });
}
