import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/screens/encuesta_apariencia.dart';
import 'package:nana_app/screens/panel_adulto.dart';
import 'package:nana_app/screens/senas.dart';

// Un celular alto, para que las pantallas largas quepan sin desplazar tanto.
void _celular(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1800);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'La encuesta pregunta cómo prefiere usar NANA y termina en el panel',
    (tester) async {
      _celular(tester);
      await tester.pumpWidget(const MaterialApp(home: EncuestaApariencia()));

      await tester.tap(find.text('Así está bien'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo prefieres usar NANA?'), findsOneWidget);

      await tester.tap(find.text('Que me hable'));
      await tester.pump();
      expect(Ajustes.queMeHable.value, isTrue);

      await tester.ensureVisible(find.text('Listo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(PanelAdulto), findsOneWidget);
      Ajustes.queMeHable.value = false;
    },
  );

  testWidgets('Sin el "sí" de la persona la cámara no se abre', (tester) async {
    _celular(tester);
    await tester.pumpWidget(const MaterialApp(home: PanelAdulto()));

    await tester.scrollUntilVisible(
      find.text('Hablar con señas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Hablar con señas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hablar con señas'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentimientoCamara), findsOneWidget);

    await tester.ensureVisible(find.text('No, gracias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, gracias'));
    await tester.pumpAndSettle();
    expect(find.byType(CamaraSenas), findsNothing);
    expect(find.byType(PanelAdulto), findsOneWidget);
  });

  testWidgets('"Ya me la tomé" en el recordatorio marca la medicina', (
    tester,
  ) async {
    _celular(tester);
    await tester.pumpWidget(const MaterialApp(home: PanelAdulto()));
    expect(find.text('Hoy llevas 1 de 4'), findsOneWidget);

    // El recordatorio tiene una animación que no para: se avanza a mano.
    await tester.tap(find.text('Toca ahora · Una pastilla con agua'));
    await tester.pump(); // el primer cuadro de una ruta nueva va oculto
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ya me la tomé'), findsOneWidget);

    await tester.tap(find.text('Ya me la tomé'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hoy llevas 2 de 4', skipOffstage: false), findsOneWidget);
  });
}
