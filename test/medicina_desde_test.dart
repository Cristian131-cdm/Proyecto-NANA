import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nana_app/core/dia.dart';
import 'package:nana_app/core/semana.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/screens/pestana_medicamentos.dart';

// Alta el 25 de nov a las 8:40 pm, «cada 12 horas» con primera toma 8:45 pm.
final alta = DateTime(2026, 11, 25, 20, 40);
Medicamento toma(int h, {String? id}) {
  final hora = TimeOfDay(hour: h, minute: 45);
  return Medicamento(
    id: id,
    nombre: 'Amoxicilina',
    dosis: '500 mg',
    hora: hora,
    ventanaMin: 30,
    desde: Medicamento.primerDia(hora, alta),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('la toma que ya pasó hoy empieza mañana', () {
    expect(
      Medicamento.primerDia(const TimeOfDay(hour: 8, minute: 45), alta),
      DateTime(2026, 11, 26),
    );
    expect(
      Medicamento.primerDia(const TimeOfDay(hour: 21, minute: 0), alta),
      DateTime(2026, 11, 25),
    );
  });

  test('el día del alta solo sale la de la noche; al otro día las dos', () {
    final meds = [toma(8, id: 'a'), toma(20, id: 'b')];
    List<String> medicinas(DateTime ahora) => [
      for (final a in diaDelAdulto(meds: meds, hoy: const [], ahora: ahora))
        if (a.tipo == TipoActividad.medicina) a.hora,
    ];
    expect(medicinas(DateTime(2026, 11, 25, 21)), ['8:45 pm']);
    expect(medicinas(DateTime(2026, 11, 26, 7)), ['8:45 am', '8:45 pm']);
  });

  test('la que empieza mañana no «falta» hoy ni cuenta en la semana', () {
    final meds = [toma(8, id: 'a'), toma(20, id: 'b')];
    final noche = DateTime(2026, 11, 25, 23, 30);
    expect(
      sinConfirmar(meds: meds, hoy: const [], ahora: noche).map((m) => m.id),
      ['b'],
    );
    final dias = semana(
      meds: meds,
      rutinas: const [],
      registros: const [],
      hoy: noche,
    );
    // Antes del 25 no había medicina: no son días de «faltó».
    expect(dias.first.posibles, 0);
    expect(dias.last.posibles, 1); // el 25 solo tocaba la de la noche
  });

  group('editar medicina', () {
    Future<List<Medicamento>> editar(
      WidgetTester t,
      List<Medicamento> existentes,
      Future<void> Function() cambios,
      List<String> borrados,
    ) async {
      final guardadas = <Medicamento>[];
      await t.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FormularioMedicamento(
                    existentes: existentes,
                    onGuardar: guardadas.add,
                    onBorrar: borrados.add,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      await cambios();
      await t.ensureVisible(find.text('Guardar cambios'));
      await t.tap(find.text('Guardar cambios'));
      await t.pumpAndSettle();
      return guardadas;
    }

    testWidgets('viene lleno y conserva los ids', (t) async {
      Servicios.reloj = () => DateTime(2026, 11, 26, 9);
      addTearDown(() => Servicios.reloj = DateTime.now);
      final borrados = <String>[];
      final guardadas = await editar(
        t,
        [toma(8, id: 'a'), toma(20, id: 'b')],
        () async {
          expect(find.text('Editar medicina'), findsOneWidget);
          expect(find.text('Amoxicilina'), findsOneWidget);
          expect(find.text('500'), findsOneWidget);
          expect(find.text('Primera toma: 8:45 am'), findsOneWidget);
        },
        borrados,
      );
      expect(guardadas.map((m) => (m.id, horaCorta(m.hora))), [
        ('a', '8:45 am'),
        ('b', '8:45 pm'),
      ]);
      // Conservó su hora → conserva desde cuándo cuenta.
      expect(guardadas.first.desde, DateTime(2026, 11, 26));
      expect(borrados, isEmpty);
    });

    testWidgets('pasar a «una vez al día» borra la toma que sobra', (t) async {
      final borrados = <String>[];
      final guardadas = await editar(
        t,
        [toma(8, id: 'a'), toma(20, id: 'b')],
        () async {
          await t.tap(find.text('Una vez al día'));
          await t.pump();
        },
        borrados,
      );
      expect(guardadas.map((m) => m.id), ['a']);
      expect(borrados, ['b']);
    });
  });

  testWidgets('en la lista la toma nueva dice «Desde mañana» y hay ✏️', (
    t,
  ) async {
    Servicios.reloj = () => DateTime(2026, 11, 25, 21);
    addTearDown(() => Servicios.reloj = DateTime.now);
    final repo = RepositorioMemoria(reloj: () => DateTime(2026, 11, 25, 21));
    Servicios.repo = repo;
    await repo.guardarMedicamento('rosa', toma(8));
    await repo.guardarMedicamento('rosa', toma(20));
    await t.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PestanaMedicamentos(folio: 'rosa')),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Desde mañana'), findsOneWidget);
    expect(find.byTooltip('Editar Amoxicilina'), findsOneWidget);
    await t.tap(find.byTooltip('Editar Amoxicilina'));
    await t.pumpAndSettle();
    expect(find.text('Editar medicina'), findsOneWidget);
  });
}
