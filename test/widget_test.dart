import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/main.dart';
import 'package:nana_app/screens/panel_adulto.dart';
import 'package:nana_app/screens/panel_cuidador.dart';

// Las pruebas no tienen internet; usa la fuente del sistema.
Widget _envolver(Widget pantalla) => MaterialApp(home: pantalla);

// Los circulitos del día del inicio (su etiqueta para el lector).
Finder _miDia([String cuenta = '', bool skipOffstage = true]) =>
    find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label ?? '').startsWith('Mi día: llevas $cuenta'),
      skipOffstage: skipOffstage,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  // Sin sesión, para que después del splash salga la bienvenida.
  setUp(() => Servicios.repo = RepositorioMemoria(sesion: null));

  testWidgets('Después del splash aparece la selección de rol', (tester) async {
    await tester.pumpWidget(const NanaApp());
    // 0.4 s de pausa y 6 s de animación.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Soy la persona mayor'), findsNothing);
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Soy la persona mayor'), findsOneWidget);
    expect(find.text('Cuido a alguien'), findsOneWidget);
  });

  testWidgets('Tocar el splash lo salta', (tester) async {
    await tester.pumpWidget(const NanaApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('Soy la persona mayor'), findsOneWidget);
  });

  testWidgets('El adulto marca su medicina con "Ya"', (tester) async {
    Servicios.repo = RepositorioMemoria(sesion: 'rosa-cel');
    await tester.pumpWidget(_envolver(const PanelAdulto()));
    await tester.pumpAndSettle();

    expect(_miDia('0 de 4'), findsOneWidget);
    await tester.ensureVisible(find.text('Ya me la tomé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya me la tomé'));
    await tester.pump();
    // El contador quedó arriba, fuera de la vista tras desplazar.
    await tester.pump();
    expect(_miDia('1 de 4', false), findsOneWidget);
    // Festejo con la palomita y luego "Deshacer", que quita lo anotado.
    expect(find.text('¡Muy bien!\nAnoté tu medicina'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(_miDia('0 de 4', false), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('El cuidador confirma la medicina vencida y cambia de pestaña', (
    tester,
  ) async {
    final hoy = DateTime.now();
    Servicios.reloj = () => DateTime(hoy.year, hoy.month, hoy.day, 9);
    addTearDown(() => Servicios.reloj = DateTime.now);
    Servicios.repo = RepositorioMemoria();
    // Alto, para que toda la pestaña Hoy quepa sin desplazarse.
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_envolver(const PanelCuidador()));
    await tester.pumpAndSettle();

    expect(find.text('Losartán · 8:00'), findsOneWidget);
    expect(find.text('Sin confirmar'), findsOneWidget);
    await tester.tap(find.text('Ya la tomó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, ya se la tomó'));
    await tester.pumpAndSettle();
    expect(find.text('Rosa va bien hoy'), findsOneWidget);
    // La línea completa del día está detrás de «Ver todo el día».
    expect(find.text('Tomó Losartán 50 mg'), findsNothing);
    await tester.tap(find.text('Ver todo el día'));
    await tester.pumpAndSettle();
    expect(find.text('Tomó Losartán 50 mg'), findsOneWidget);

    // El expediente ahora está en «Más».
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Su expediente'));
    await tester.pumpAndSettle();
    expect(find.text('Recetas'), findsOneWidget);
  });
}
