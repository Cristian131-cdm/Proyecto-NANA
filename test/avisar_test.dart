import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/panel_adulto.dart';
import 'package:nana_app/screens/panel_cuidador.dart';

Future<void> _pedirAyuda(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: PanelAdulto()));
  await t.pumpAndSettle();
  await t.tap(find.text('Necesito ayuda'));
  await t.pumpAndSettle();
  await t.tap(find.text('Sí, avisar'));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Avisar a mi familia crea una alerta de verdad', (t) async {
    final repo = RepositorioMemoria(sesion: 'rosa-cel');
    Servicios.repo = repo;
    await _pedirAyuda(t);

    expect(find.text('Listo, ya le avisé a tu familia'), findsOneWidget);
    expect(await repo.alertasSinAtender('rosa').first, hasLength(1));
  });

  testWidgets('Sin internet no dice que ya avisó', (t) async {
    Servicios.repo = RepositorioMemoria(sesion: 'rosa-cel')..sinInternet = true;
    await _pedirAyuda(t);

    expect(find.text('No hay internet. Lo mando en cuanto haya'), findsOneWidget);
    expect(find.text('Listo, ya le avisé a tu familia'), findsNothing);
  });

  testWidgets('Sin familia conectada no finge el aviso', (t) async {
    final repo = RepositorioMemoria(sesion: null);
    await repo.registrarAdulto(
      nombre: 'Carmen',
      apellidos: '',
      correo: 'carmen@gmail.com',
      contrasena: 'secreto1',
    );
    Servicios.repo = repo;
    await t.pumpWidget(const MaterialApp(home: PanelAdulto()));
    await t.pumpAndSettle();
    await t.tap(find.text('Necesito ayuda'));
    await t.pumpAndSettle();

    expect(find.text('Todavía no tienes familia conectada'), findsOneWidget);
    expect(find.text('Sí, avisar'), findsNothing);
  });

  testWidgets('La familia ve la alerta y la marca como atendida', (t) async {
    final repo = RepositorioMemoria();
    Servicios.repo = repo;
    await repo.pedirAyuda('rosa');
    await t.pumpWidget(const MaterialApp(home: PanelCuidador()));
    await t.pumpAndSettle();

    expect(find.text('Rosa pidió ayuda'), findsOneWidget);
    await t.tap(find.text('Ya lo atendí'));
    await t.pumpAndSettle();
    expect(find.text('Rosa pidió ayuda'), findsNothing);
  });
}
