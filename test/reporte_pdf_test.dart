import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/reporte_pdf.dart';
import 'package:nana_app/core/semana.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/registro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hoy = DateTime(2026, 11, 12, 20); // jueves
  const losartan = Medicamento(
    id: 'losartan',
    nombre: 'Losartán',
    dosis: '50 mg',
    hora: TimeOfDay(hour: 8, minute: 0),
    ventanaMin: 30,
  );

  bool esPdf(List<int> bytes) => ascii.decode(bytes.sublist(0, 4)) == '%PDF';

  test('Con la semana vacía sale un PDF', () async {
    final dias = semana(
      meds: const [],
      rutinas: const [],
      registros: const [],
      hoy: hoy,
    );
    final bytes = await reporteSemanaPdf('Rosa', dias, generado: hoy);
    expect(esPdf(bytes), isTrue);
  });

  test('Con registros, acentos y un emoji sale un PDF', () async {
    final dias = semana(
      meds: const [losartan],
      rutinas: const [],
      registros: [
        Registro(
          tipo: TipoActividad.medicina,
          titulo: 'Losartán 50 mg',
          idMedicamento: 'losartan',
          fecha: DateTime(2026, 11, 11, 8, 5),
          registradoPor: 'rosa-cel',
        ),
        Registro(
          tipo: TipoActividad.animo,
          titulo: 'Mal',
          valor: 3,
          fecha: DateTime(2026, 11, 11, 9),
          registradoPor: 'rosa-cel',
        ),
        Registro(
          tipo: TipoActividad.mensaje,
          titulo: '¿Ya vienes? Te extraño 💜 — mamá',
          fecha: DateTime(2026, 11, 12, 10),
          registradoPor: 'rosa-cel',
        ),
      ],
      hoy: hoy,
    );
    final bytes = await reporteSemanaPdf('Rosa María 🌷', dias, generado: hoy);
    expect(esPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(2000));
  });

  test('Muchos registros pasan a más de una hoja sin tronar', () async {
    final dias = semana(
      meds: const [],
      rutinas: const [],
      registros: [
        for (var i = 0; i < 200; i++)
          Registro(
            tipo: TipoActividad.mensaje,
            titulo: 'Frase número $i',
            fecha: DateTime(2026, 11, 6 + i % 7, 8, i % 60),
            registradoPor: 'rosa-cel',
          ),
      ],
      hoy: hoy,
    );
    expect(esPdf(await reporteSemanaPdf('Rosa', dias, generado: hoy)), isTrue);
  });

  test('El texto del PDF conserva acentos y quita lo que no se dibuja', () {
    expect(
      textoPdf('¿Cómo está la abuela Ñoña?'),
      '¿Cómo está la abuela Ñoña?',
    );
    expect(textoPdf('Hola 💜 mamá'), 'Hola mamá');
    expect(textoPdf('“bien” — dijo'), '"bien" - dijo');
  });

  test('El archivo se llama con el adulto y la fecha', () {
    expect(
      nombreReporte('Rosa María', DateTime(2026, 11, 2)),
      'NANA_semana_Rosa_María_2026-11-02.pdf',
    );
  });
}
