import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/semana.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/registro.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/pestana_historial.dart';
import 'package:nana_app/screens/pestana_rutinas.dart';

Widget _envolver(Widget pantalla) =>
    MaterialApp(home: Scaffold(body: pantalla));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Servicios.reloj = () => DateTime(2026, 11, 8, 12); // domingo
    Servicios.repo = RepositorioMemoria(reloj: Servicios.reloj);
  });

  test('Los días se escriben como se leen', () {
    expect(textoDias({0, 1, 2, 3, 4, 5, 6}), 'Todos los días');
    expect(textoDias({0, 1, 2, 3, 4}), 'Lunes a viernes');
    expect(textoDias({1, 3}), 'Martes y jueves');
    expect(textoDias({0, 2, 4}), 'Lunes, miércoles y viernes');
  });

  test('El resumen de la semana sale de los registros reales', () {
    const losartan = Medicamento(
      id: 'losartan',
      nombre: 'Losartán',
      dosis: '50 mg',
      hora: TimeOfDay(hour: 8, minute: 0),
      ventanaMin: 30,
    );
    Registro tomo(int dia) => Registro(
      tipo: TipoActividad.medicina,
      titulo: 'Losartán 50 mg',
      idMedicamento: 'losartan',
      fecha: DateTime(2026, 11, dia, 8, 5),
      registradoPor: 'rosa-cel',
    );
    // Del lunes 2 al domingo 8; faltó el miércoles 4.
    final dias = semana(
      meds: const [losartan],
      rutinas: const [],
      registros: [
        for (final d in [2, 3, 5, 6, 7, 8]) tomo(d),
        Registro(
          tipo: TipoActividad.animo,
          titulo: 'Mal',
          valor: 3,
          fecha: DateTime(2026, 11, 8, 19, 40),
          registradoPor: 'rosa-cel',
        ),
      ],
      hoy: DateTime(2026, 11, 8, 20),
    );
    expect(dias.length, 7);
    expect(dias.first.nombre, 'lunes');
    expect(dias.last.horaMal, isNotNull);
    final texto = resumenSemana('Rosa', dias);
    expect(texto, contains('Medicinas a tiempo: 6 de 7'));
    expect(texto, contains('faltó el miércoles'));
    expect(texto, contains('Del 2 al 8 de noviembre'));
    expect(texto, contains('No da recomendaciones médicas'));
  });

  testWidgets('Agregar una rutina la muestra en la lista', (tester) async {
    await tester.pumpWidget(_envolver(const PestanaRutinas(folio: 'rosa')));
    await tester.tap(find.text('Agregar rutina'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tomar agua');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tomar agua'), findsOneWidget);
  });

  testWidgets('Agregar una receta la muestra en la lista', (tester) async {
    await tester.pumpWidget(
      _envolver(const PestanaHistorial(adulto: 'Rosa', folio: 'rosa')),
    );
    await tester.tap(find.text('Agregar receta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Dr. López');
    await tester.enterText(find.byType(TextField).at(1), 'Omeprazol 20 mg');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Omeprazol 20 mg'), findsOneWidget);
  });

  testWidgets('La alerta de "pide ayuda" no se puede apagar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
      ),
    );
    await tester.scrollUntilVisible(find.text('Cuando pide ayuda'), 200);

    final interruptores = tester
        .widgetList<Switch>(find.byType(Switch))
        .toList();
    expect(interruptores.length, 3);
    expect(interruptores.last.value, isTrue);
    expect(interruptores.last.onChanged, isNull);
  });

  testWidgets('Agregar una cita la guarda y la muestra', (tester) async {
    await tester.pumpWidget(
      _envolver(const PestanaHistorial(adulto: 'Rosa', folio: 'rosa')),
    );
    await tester.scrollUntilVisible(find.text('Agregar cita'), 200);
    await tester.tap(find.text('Agregar cita'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Cardiología');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Cardiología'), findsOneWidget);
  });

  testWidgets('Apagar una regla de alerta se guarda', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Medicina sin confirmar'), 200);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final reglas = await Servicios.repo.reglasAlerta('rosa').first;
    expect(reglas.medicina, isFalse);
  });
}
