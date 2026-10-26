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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  // Sin sesión, para que después del splash salga la bienvenida.
  setUp(() => Servicios.repo = RepositorioMemoria(sesion: null));

  testWidgets('Después del splash aparece la selección de rol',
      (tester) async {
    await tester.pumpWidget(const NanaApp());
    // 0.4 s de pausa y 6 s de animación.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Soy adulto mayor'), findsNothing);
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Soy adulto mayor'), findsOneWidget);
    expect(find.text('Soy cuidador o familiar'), findsOneWidget);
  });

  testWidgets('Tocar el splash lo salta', (tester) async {
    await tester.pumpWidget(const NanaApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('Soy adulto mayor'), findsOneWidget);
  });

  testWidgets('El adulto marca su medicina con "Ya"', (tester) async {
    await tester.pumpWidget(_envolver(const PanelAdulto()));

    expect(find.text('Hoy llevas 1 de 4'), findsOneWidget);
    await tester.ensureVisible(find.text('Ya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya'));
    await tester.pump();
    // El contador quedó arriba, fuera de la vista tras desplazar.
    expect(find.text('Hoy llevas 2 de 4', skipOffstage: false), findsOneWidget);
  });

  testWidgets('El cuidador resuelve la alerta y cambia de pestaña',
      (tester) async {
    await tester.pumpWidget(_envolver(const PanelCuidador()));

    expect(find.text('Losartán de las 8:00 sin confirmar'), findsOneWidget);
    await tester.tap(find.text('Ya lo resolví'));
    await tester.pumpAndSettle();
    expect(find.text('Rosa va bien hoy'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Recetas'), findsOneWidget);
  });
}
