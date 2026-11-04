import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/mi_familia.dart';
import 'package:nana_app/screens/nana_escucha.dart';
import 'package:nana_app/screens/panel_adulto.dart';

void _celular(WidgetTester t) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(420, 900);
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Servicios.repo = RepositorioMemoria(sesion: 'rosa-cel'));

  testWidgets('El inicio cabe sin bajar: tarjeta y los tres botones', (
    t,
  ) async {
    _celular(t);
    await t.pumpWidget(const MaterialApp(home: PanelAdulto()));
    await t.pumpAndSettle();

    expect(find.textContaining('Rosa'), findsOneWidget);
    for (final boton in ['Hablar', 'Familia', 'Necesito ayuda']) {
      expect(find.text(boton).hitTestable(), findsOneWidget, reason: boton);
    }
    expect(find.text('Ver todo mi día').hitTestable(), findsOneWidget);
    // Ya no están en el inicio: se movieron a "Hablar".
    expect(find.text('Frases rápidas'), findsNothing);
    expect(find.text('Hablar con señas'), findsNothing);
  });

  testWidgets('El inicio aguanta la letra muy grande', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(360, 800);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: PanelAdulto(),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Un desbordamiento lanza una excepción y haría fallar la prueba.
    expect(t.takeException(), isNull);
    expect(find.text('Necesito ayuda'), findsOneWidget);
  });

  testWidgets('Una frase en "Hablar" regresa al inicio y se anota', (t) async {
    _celular(t);
    final dichas = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NanaEscucha(nombre: 'Rosa', onFrase: dichas.add),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Te escucho, Rosa'), findsOneWidget);

    await t.tap(find.text('Ya comí'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(dichas, ['Ya comí']);
    expect(find.byType(NanaEscucha), findsNothing);
  });

  testWidgets('Mi familia muestra a la familia real con su botón de llamar', (
    t,
  ) async {
    _celular(t);
    await t.pumpWidget(const MaterialApp(home: MiFamilia(folio: 'rosa')));
    await t.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Llamar a Ana'), findsOneWidget);
  });

  testWidgets('Sin familia conectada lo dice en vez de inventar contactos', (
    t,
  ) async {
    _celular(t);
    await t.pumpWidget(const MaterialApp(home: MiFamilia(folio: 'nadie')));
    await t.pumpAndSettle();
    expect(find.text('Todavía no tienes familia conectada'), findsOneWidget);
  });
}
