import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/biometria.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/alta_adulto.dart';
import 'package:nana_app/screens/bienvenida.dart';
import 'package:nana_app/screens/cuenta_cuidador.dart';
import 'package:nana_app/screens/entrar_con_codigo.dart';
import 'package:nana_app/screens/unirme_con_codigo.dart';

// La entrada nueva: tres caminos (persona mayor, quien cuida, invitado), el
// código del invitado que se revisa solo, «Otro» con campo y el registro del
// encargado en pasos.

class _SinHuella implements Biometria {
  @override
  Future<bool> disponible() async => false;
  @override
  Future<bool> autenticar(String motivo) async => false;
}

Future<void> _esperar(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _bajarYTocar(WidgetTester t, String texto) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump();
  await t.scrollUntilVisible(
    find.text(texto),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(find.text(texto));
}

Future<void> _escribir(WidgetTester t, String etiqueta, String texto) async {
  final campo = find.widgetWithText(TextField, etiqueta);
  await t.scrollUntilVisible(
    campo,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.enterText(campo, texto);
}

void main() {
  late RepositorioMemoria repo;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    Servicios.reloj = () => DateTime(2026, 11, 18, 12);
    repo = RepositorioMemoria(reloj: Servicios.reloj);
    Servicios.repo = repo;
    Servicios.biometria = _SinHuella();
  });

  Future<void> abrir(WidgetTester t, Widget pantalla) async {
    await t.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(home: pantalla));
    await t.pumpAndSettle();
  }

  testWidgets('La entrada tiene tres caminos y cada uno lleva a lo suyo', (
    t,
  ) async {
    await repo.cerrarSesion();
    await abrir(t, const Bienvenida());
    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('Ya tengo cuenta · Iniciar sesión'), findsOneWidget);

    await t.tap(find.text('Soy la persona mayor'));
    await t.pumpAndSettle();
    expect(find.byType(EntrarConCodigo), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();

    await t.tap(find.text('Cuido a alguien'));
    await t.pumpAndSettle();
    expect(find.byType(OpcionesCuidador), findsOneWidget);
    expect(find.text('Le das un código para su celular'), findsOneWidget);
    // El enlace de invitación ya no vive aquí: el invitado tiene su botón.
    expect(find.text('Tengo un código de invitación'), findsNothing);
    await t.pageBack();
    await t.pumpAndSettle();

    await t.tap(find.text('Me invitaron'));
    await t.pumpAndSettle();
    expect(find.byType(InvitadoConCodigo), findsOneWidget);
  });

  testWidgets('Con los 6 números dice a quién va a acompañar', (t) async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await repo.cerrarSesion();
    await abrir(t, const InvitadoConCodigo());

    await t.enterText(find.byType(TextField), codigo.codigo.substring(0, 5));
    await t.pumpAndSettle();
    expect(find.textContaining('Vas a acompañar'), findsNothing);

    await t.enterText(find.byType(TextField), codigo.codigo);
    await t.pumpAndSettle();
    expect(
      find.text('Vas a acompañar a Rosa. Te invitó Ana.'),
      findsOneWidget,
    );
    await _bajarYTocar(t, 'Continuar');
    await t.pumpAndSettle();
    expect(find.text('Vas a acompañar a Rosa'), findsOneWidget);
    expect(find.text('Ya tengo cuenta en NANA'), findsOneWidget);
  });

  testWidgets('«Otro» pide escribir qué es y guarda lo escrito', (t) async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await repo.cerrarSesion();
    await abrir(t, const InvitadoConCodigo());
    await t.enterText(find.byType(TextField), codigo.codigo);
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Continuar');
    await t.pumpAndSettle();

    await _escribir(t, 'Nombre', 'Lupe');
    await _escribir(t, 'Celular (10 números)', '5500000004');
    await _escribir(t, 'Correo', 'lupe@gmail.com');
    await _escribir(t, 'Contraseña', 'secreto1');
    await _bajarYTocar(t, 'otro');
    await t.pumpAndSettle();
    // «Otro» sin escribir no deja crear la cuenta.
    await _bajarYTocar(t, 'Crear mi cuenta');
    await t.pumpAndSettle();
    expect(find.text('Escribe qué es tuyo'), findsOneWidget);
    expect(repo.uid, isNull);

    await _escribir(t, 'Escribe qué es tuyo (ej. sobrina, vecina)', 'vecina');
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Crear mi cuenta');
    await _esperar(t);
    expect(find.text('Ya acompañas a Rosa'), findsOneWidget);
    expect((await repo.adultosACargo().first).single.parentesco, 'vecina');
  });

  testWidgets('Quien ya tiene cuenta entra con ella y se une', (t) async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await repo.crearCuentaCuidador(
      nombre: 'Luis',
      apellidos: 'López',
      telefono: '5500000003',
      correo: 'luis@gmail.com',
      contrasena: 'secreto1',
    );
    await repo.cerrarSesion();
    await abrir(t, const InvitadoConCodigo());
    await t.enterText(find.byType(TextField), codigo.codigo);
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Continuar');
    await t.pumpAndSettle();

    await _bajarYTocar(t, 'Ya tengo cuenta en NANA');
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nombre'), findsNothing);
    await _escribir(t, 'Correo', 'luis@gmail.com');
    await _escribir(t, 'Contraseña', 'secreto1');
    await _bajarYTocar(t, 'mamá');
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Entrar y unirme');
    await _esperar(t);

    expect(find.text('Ya acompañas a Rosa'), findsOneWidget);
    expect((await repo.familiaDe('rosa').first).map((f) => f.nombre), [
      'Ana',
      'Luis',
    ]);
  });

  testWidgets('El registro nuevo va de «Paso 1 de 6» a «Paso 5 de 6»', (
    t,
  ) async {
    await repo.cerrarSesion();
    await abrir(t, const CuentaCuidador(crear: true));
    expect(find.text('Paso 1 de 6'), findsOneWidget);
    expect(find.text('Primero, tu cuenta'), findsOneWidget);

    // Ya con cuenta (Ana), sigue el alta.
    await repo.iniciarSesion('ana@nana.mx', 'secreto1');
    await abrir(t, const AltaAdulto(desdeRegistro: true));
    expect(find.text('Paso 2 de 6'), findsOneWidget);
    expect(find.text('¿Te invitaron? Usa tu código'), findsNothing);

    await _escribir(t, 'Nombre', 'Rosa');
    await _bajarYTocar(t, 'mamá');
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Siguiente');
    await t.pumpAndSettle();
    expect(find.text('Paso 3 de 6'), findsOneWidget);
    await _bajarYTocar(t, 'Estoy de acuerdo y Rosa también lo sabe');
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Continuar');
    await t.pumpAndSettle();
    expect(find.text('Paso 4 de 6'), findsOneWidget);
    await _bajarYTocar(t, 'Sí, tiene celular');
    await _esperar(t);
    expect(find.text('Paso 5 de 6'), findsOneWidget);
  });

  testWidgets('«Cuidar a otra persona» (ya con cuenta) va de 1 a 5', (
    t,
  ) async {
    await abrir(t, const AltaAdulto());
    expect(find.text('Paso 1 de 5'), findsOneWidget);
    // Quien ya tiene cuenta entra por aquí si lo invitan.
    expect(find.text('¿Te invitaron? Usa tu código'), findsOneWidget);
    expect(find.byType(UnirmeConCodigo), findsNothing);
  });
}
