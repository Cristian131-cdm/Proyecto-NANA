import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/pestana_historial.dart';
import 'package:nana_app/screens/pestana_rutinas.dart';
import 'package:nana_app/screens/pestana_semana.dart';

Widget _envolver(Widget pantalla) =>
    MaterialApp(home: Scaffold(body: pantalla));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('Los días se escriben como se leen', () {
    expect(textoDias({0, 1, 2, 3, 4, 5, 6}), 'Todos los días');
    expect(textoDias({0, 1, 2, 3, 4}), 'Lunes a viernes');
    expect(textoDias({1, 3}), 'Martes y jueves');
    expect(textoDias({0, 2, 4}), 'Lunes, miércoles y viernes');
  });

  test('El código de invitación no usa 0, O, 1 ni I', () {
    final codigo = generarCodigo(Random(1));
    expect(codigo.length, 6);
    expect(RegExp(r'[01OI]').hasMatch(codigo), isFalse);
  });

  test('El resumen de la semana trae medicinas y ánimo', () {
    final texto = PestanaSemana.resumen('Rosa');
    expect(texto, contains('Medicinas a tiempo: 12 de 14'));
    expect(texto, contains('faltó el miércoles y el domingo'));
    expect(texto, contains('No da recomendaciones médicas'));
  });

  testWidgets('Agregar una rutina la muestra en la lista', (tester) async {
    await tester.pumpWidget(_envolver(const PestanaRutinas()));
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tomar agua');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tomar agua'), findsOneWidget);
  });

  testWidgets('Agregar una receta la muestra en la lista', (tester) async {
    await tester.pumpWidget(_envolver(const PestanaHistorial(adulto: 'Rosa')));
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
        const MaterialApp(home: FamiliaAlertas(adulto: 'Rosa')));
    await tester.scrollUntilVisible(find.text('Cuando pide ayuda'), 200);

    final interruptores =
        tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(interruptores.length, 3);
    expect(interruptores.last.value, isTrue);
    expect(interruptores.last.onChanged, isNull);
  });
}
