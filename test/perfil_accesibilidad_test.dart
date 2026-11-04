import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/perfil_accesibilidad.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/salud.dart';
import 'package:nana_app/screens/panel_adulto.dart';
import 'package:nana_app/screens/tablero_frases.dart';

void _reiniciar() {
  Ajustes.escalaTexto.value = 1.0;
  Ajustes.discapacidadesAplicadas.value = '';
  for (final n in [
    Ajustes.sinVoz,
    Ajustes.pantallaEsBoton,
    Ajustes.queMeHable,
    Ajustes.conSenas,
    Ajustes.altoContraste,
    Ajustes.avisoVibracion,
  ]) {
    n.value = false;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(_reiniciar);
  tearDown(_reiniciar);

  test('Sin discapacidades no cambia nada', () {
    final p = perfilDe(const []);
    expect(p.sinVoz, isFalse);
    expect(p.pantallaEsBoton, isFalse);
    expect(p.escalaTexto, isNull);
    expect(p.altoContraste, isFalse);
  });

  test('Cada discapacidad prende lo suyo', () {
    expect(perfilDe(const ['No habla']).sinVoz, isTrue);
    final noVe = perfilDe(const ['No ve bien']);
    expect(noVe.pantallaEsBoton, isTrue);
    expect(noVe.escalaTexto, 1.5);
    expect(noVe.queMeHable, isTrue);
    final noOye = perfilDe(const ['No oye bien']);
    expect(noOye.avisoVibracion, isTrue);
    expect(noOye.conSenas, isTrue);
    expect(perfilDe(const ['Daltonismo']).altoContraste, isTrue);
  });

  test('Varias juntas se suman', () {
    final p = perfilDe(const ['No habla', 'No oye bien']);
    expect(p.sinVoz, isTrue);
    expect(p.avisoVibracion, isTrue);
    expect(p.queMeHable, isFalse);
  });

  test('Si la persona apaga un ajuste, no se vuelve a prender solo', () {
    aplicarPerfil(const ['No oye bien']);
    expect(Ajustes.avisoVibracion.value, isTrue);

    Ajustes.avisoVibracion.value = false; // lo apagó en "Aa"
    aplicarPerfil(const ['No oye bien']); // llega otra vez lo mismo
    expect(Ajustes.avisoVibracion.value, isFalse);

    aplicarPerfil(const ['No oye bien', 'No habla']); // la familia cambió algo
    expect(Ajustes.sinVoz.value, isTrue);
  });

  test('No baja la letra si ya la tenía más grande', () {
    Ajustes.escalaTexto.value = 1.5;
    aplicarPerfil(const ['No ve bien']);
    expect(Ajustes.escalaTexto.value, 1.5);
  });

  testWidgets('Con "No habla" el botón dice "Decir" y abre el tablero', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(420, 900);
    addTearDown(t.view.reset);
    final repo = RepositorioMemoria(sesion: 'rosa-cel');
    Servicios.repo = repo;
    await repo.guardarSalud('rosa', const Salud(discapacidades: ['No habla']));

    await t.pumpWidget(const MaterialApp(home: PanelAdulto()));
    await t.pumpAndSettle();
    expect(find.text('Hablar'), findsNothing);

    await t.tap(find.text('Decir'));
    await t.pumpAndSettle();
    expect(find.byType(TableroFrases), findsOneWidget);

    await t.tap(find.text('Ya comí'));
    await t.pumpAndSettle();
    expect(find.text('Anotado: Ya comí'), findsOneWidget);
  });
}
