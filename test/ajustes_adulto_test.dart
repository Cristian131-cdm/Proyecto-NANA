import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/biometria.dart';
import 'package:nana_app/core/perfil_accesibilidad.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/models/apariencia.dart';
import 'package:nana_app/widgets/ajustes_texto.dart';

// La huella real deja temporizadores en pruebas.
class _ConHuella implements Biometria {
  @override
  Future<bool> disponible() async => true;
  @override
  Future<bool> autenticar(String motivo) async => true;
}

void _reiniciar() {
  Ajustes.escalaTexto.value = 1.0;
  Ajustes.queMeHable.value = false;
  Ajustes.altoContraste.value = false;
  Ajustes.oyeNana.value = false;
  Ajustes.velocidadVoz.value = 1.0;
  Ajustes.sinVoz.value = false;
  Ajustes.aparienciaAplicada.value = '';
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late VozNula voz;
  setUp(() {
    _reiniciar();
    voz = VozNula();
    Servicios.voz = voz;
    Servicios.biometria = _ConHuella();
  });
  tearDown(_reiniciar);

  Future<void> abrir(WidgetTester t, {VoidCallback? salir}) async {
    await t.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HojaAjustesAdulto(onCerrarSesion: salir)),
      ),
    );
  }

  testWidgets('solo 4 botones grandes, sin explicaciones ni lo que no sirve', (
    t,
  ) async {
    await abrir(t);
    for (final b in ['Letra', 'Que me hable', 'Colores fuertes', 'Oye NANA']) {
      expect(find.text(b), findsOneWidget, reason: b);
    }
    for (final no in [
      'Con señas',
      'Avisos con vibración y luz',
      'Menos movimiento',
      'Contestar tocando',
      'NANA lee en voz alta y te pregunta',
      'Salir de NANA en este celular',
      '¿Qué tan rápido te hablo?',
    ]) {
      expect(find.text(no), findsNothing, reason: no);
    }
    // El estado se dice en palabras, no solo con color.
    expect(find.text('Apagado'), findsNWidgets(3));
  });

  testWidgets('cada toque en Letra cambia el tamaño y NANA lo dice', (t) async {
    await abrir(t);
    await t.tap(find.text('Letra'));
    await t.pump();
    expect(Ajustes.escalaTexto.value, 1.25);
    expect(find.text('Grande'), findsOneWidget);
    expect(voz.dicho.last, 'Listo, ahora la letra es grande');
    // Lo que dijo también queda escrito arriba.
    expect(find.text('Listo, ahora la letra es grande'), findsOneWidget);

    await t.tap(find.text('Letra'));
    await t.pump();
    expect(Ajustes.escalaTexto.value, 1.5);
    await t.tap(find.text('Letra'));
    await t.pump();
    expect(Ajustes.escalaTexto.value, 1.0);
  });

  testWidgets('prender «Que me hable» muestra la velocidad en 3 botones', (
    t,
  ) async {
    await abrir(t);
    await t.tap(find.text('Que me hable'));
    await t.pump();
    expect(Ajustes.queMeHable.value, isTrue);
    expect(find.text('✓ Prendido'), findsOneWidget);
    expect(voz.dicho.last, 'Listo, ahora te hablo');
    expect(find.text('¿Qué tan rápido te hablo?'), findsOneWidget);

    await t.tap(find.text('Despacio'));
    await t.pump();
    expect(Ajustes.velocidadVoz.value, 0.7);
    expect(voz.dicho.last, 'Así hablo despacio');

    await t.tap(find.text('Que me hable'));
    await t.pump();
    expect(find.text('¿Qué tan rápido te hablo?'), findsNothing);
  });

  testWidgets('Colores fuertes y Oye NANA se prenden y se apagan', (t) async {
    await abrir(t);
    await t.tap(find.text('Colores fuertes'));
    await t.tap(find.text('Oye NANA'));
    await t.pump();
    expect(Ajustes.altoContraste.value, isTrue);
    expect(Ajustes.oyeNana.value, isTrue);
    await t.tap(find.text('Oye NANA'));
    await t.pump();
    expect(Ajustes.oyeNana.value, isFalse);
    expect(voz.dicho.last, 'Listo, ya no te escucho');
  });

  testWidgets('salir está guardado en «Más opciones»', (t) async {
    var salio = 0;
    await abrir(t, salir: () => salio++);
    await t.tap(find.text('Más opciones'));
    await t.pump();
    await t.pump();
    expect(find.text('Entrar con huella'), findsOneWidget);
    // Con «Voz de NANA» la hoja creció: hay que bajar para ver el botón.
    await t.ensureVisible(find.text('Salir de NANA en este celular'));
    await t.pump();
    await t.tap(find.text('Salir de NANA en este celular'));
    await t.pump();
    expect(salio, 1);
  });

  test('el encargado manda contestar tocando y la velocidad', () {
    final a = const Apariencia(
      contestarTocando: true,
      velocidadVoz: 1.3,
    ).copyWith(actualizado: DateTime(2026, 11, 19));
    final b = Apariencia.deMapa(a.aMapa())!;
    expect((b.contestarTocando, b.velocidadVoz), (true, 1.3));
    aplicarApariencia(b);
    expect(Ajustes.sinVoz.value, isTrue);
    expect(Ajustes.velocidadVoz.value, 1.3);
  });
}
