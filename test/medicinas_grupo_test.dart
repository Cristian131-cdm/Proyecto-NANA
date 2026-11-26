import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nana_app/core/alarmas.dart';
import 'package:nana_app/core/dia.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/medicina_leida.dart';
import 'package:nana_app/screens/pestana_medicamentos.dart';

Medicamento lora(int h, {String? id, DateTime? hasta}) => Medicamento(
  id: id,
  nombre: 'Loratadina',
  dosis: '1 tabletas',
  hora: TimeOfDay(hour: h, minute: 5),
  ventanaMin: 30,
  hasta: hasta,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('una tarjeta por medicina', () {
    test('las 3 tomas de «cada 8 horas» son un solo grupo', () {
      final grupos = agruparMedicinas([lora(20), lora(4), lora(12)]);
      expect(grupos, hasLength(1));
      expect(grupos.single.frecuencia, 'Cada 8 horas');
      expect(grupos.single.tomas.map((m) => horaCorta(m.hora)), [
        '4:05 am',
        '12:05 pm',
        '8:05 pm',
      ]);
    });

    test('otra dosis u otro fin es otra tarjeta', () {
      final otra = Medicamento(
        nombre: 'Loratadina',
        dosis: '2 tabletas',
        hora: const TimeOfDay(hour: 9, minute: 0),
        ventanaMin: 30,
      );
      final grupos = agruparMedicinas([
        lora(8),
        otra,
        lora(20, hasta: DateTime(2026, 12, 1)),
      ]);
      expect(grupos, hasLength(3));
      expect(
        agruparMedicinas([lora(8), lora(11)]).single.frecuencia,
        '2 veces al día',
      );
    });

    testWidgets('la lista muestra una tarjeta y borrar quita todas sus tomas', (
      t,
    ) async {
      final repo = RepositorioMemoria();
      Servicios.repo = repo;
      for (final h in [4, 12, 20]) {
        await repo.guardarMedicamento('rosa', lora(h));
      }
      await t.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PestanaMedicamentos(folio: 'rosa')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Loratadina'), findsOneWidget);
      expect(find.text('1 tabletas · Cada 8 horas'), findsOneWidget);
      expect(find.text('12:05 pm'), findsOneWidget);

      await t.tap(find.byTooltip('Borrar Loratadina'));
      await t.pumpAndSettle();
      final quedan = await repo.medicamentos('rosa').first;
      expect(quedan.where((m) => m.nombre == 'Loratadina'), isEmpty);

      await t.tap(find.text('Deshacer'));
      await t.pumpAndSettle();
      final vuelven = await repo.medicamentos('rosa').first;
      expect(vuelven.where((m) => m.nombre == 'Loratadina'), hasLength(3));
      await t.pump(const Duration(seconds: 6));
    });
  });

  group('por cuántos días', () {
    test('«por 7 días» desde el 25 termina el 1 de diciembre (inclusive)', () {
      final fin = Medicamento.ultimoDia(DateTime(2026, 11, 25, 18), 7);
      expect(fin, DateTime(2026, 12, 1));
      final m = lora(8, hasta: fin);
      expect(m.vigente(DateTime(2026, 12, 1, 23, 59)), isTrue);
      expect(m.vigente(DateTime(2026, 12, 2)), isFalse);
      expect(lora(8).vigente(DateTime(2030, 1, 1)), isTrue);
    });

    test('las alarmas de un tratamiento con fin se programan día por día', () {
      final m = lora(8, id: 'm1', hasta: DateTime(2026, 11, 27));
      final tomas = tomasHastaElFin(m, DateTime(2026, 11, 25, 9));
      // Hoy a las 8:05 ya pasó: quedan el 26 y el 27.
      expect(tomas, [
        DateTime(2026, 11, 26, 8, 5),
        DateTime(2026, 11, 27, 8, 5),
      ]);
      expect(tomasHastaElFin(lora(8), DateTime(2026, 11, 25)), isEmpty);
    });

    test('la que ya terminó no aparece en ningún lado', () async {
      final repo = RepositorioMemoria(reloj: () => DateTime(2026, 12, 5));
      await repo.guardarMedicamento(
        'rosa',
        lora(8, hasta: DateTime(2026, 12, 1)),
      );
      final meds = await repo.medicamentos('rosa').first;
      expect(meds.where((m) => m.nombre == 'Loratadina'), isEmpty);
    });

    test('la receta «por 10 días» guarda el último día', () {
      const leida = MedicinaLeida(
        nombre: 'Amoxicilina',
        dosis: '500',
        unidad: 'mg',
        horas: [TimeOfDay(hour: 8, minute: 0)],
        dias: 10,
      );
      final m = leida.comoMedicamentos(desde: DateTime(2026, 11, 25)).single;
      expect(m.hasta, DateTime(2026, 12, 4));
      expect(leida.comoMedicamentos().single.hasta, isNull);
    });

    testWidgets('el formulario guarda «7 días» y muestra el último día', (
      t,
    ) async {
      Servicios.reloj = () => DateTime(2026, 11, 25, 7, 58);
      addTearDown(() => Servicios.reloj = DateTime.now);
      final guardadas = <Medicamento>[];
      await t.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormularioMedicamento(onGuardar: guardadas.add),
            ),
          ),
        ),
      );
      await t.enterText(
        find.widgetWithText(TextField, 'Medicamento'),
        'Amoxicilina',
      );
      await t.enterText(find.widgetWithText(TextField, 'Dosis'), '500');
      await t.tap(find.text('7 días'));
      await t.pump();
      expect(find.text('Último día: martes 1 dic'), findsOneWidget);
      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(guardadas.single.hasta, DateTime(2026, 12, 1));
    });

    testWidgets('«Otro» pide un número válido', (t) async {
      final guardadas = <Medicamento>[];
      await t.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormularioMedicamento(onGuardar: guardadas.add),
            ),
          ),
        ),
      );
      await t.enterText(find.widgetWithText(TextField, 'Medicamento'), 'X');
      await t.enterText(find.widgetWithText(TextField, 'Dosis'), '1');
      await t.tap(find.text('Otro'));
      await t.pump();
      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(guardadas, isEmpty);
      expect(find.text('Escribe de 1 a 365 días'), findsOneWidget);
    });
  });
}
