import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/codigo.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/alta_adulto.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/panel_cuidador.dart';

// Ana (ya cuida a Rosa) invita; después la sesión pasa a Luis, su hermano.
Future<void> _entraLuis(RepositorioMemoria repo) => repo.crearCuentaCuidador(
  nombre: 'Luis',
  apellidos: 'López',
  telefono: '5500000003',
  correo: 'luis@gmail.com',
  contrasena: 'secreto1',
);

// La lista es larga: lo de abajo no se dibuja hasta bajar.
Future<void> _bajarYTocar(WidgetTester t, String texto) async {
  await t.scrollUntilVisible(
    find.text(texto),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(find.text(texto));
}

Matcher _falla(String mensaje) =>
    throwsA(isA<ErrorNana>().having((e) => e.mensaje, 'mensaje', mensaje));

void main() {
  late RepositorioMemoria repo;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    Servicios.reloj = () => DateTime(2026, 11, 12, 12);
    repo = RepositorioMemoria(reloj: Servicios.reloj);
    Servicios.repo = repo;
  });

  test('Un familiar canjea la invitación y queda como cuidador', () async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    expect(codigo.familiar, isTrue);
    expect(normalizarCodigo(codigo.codigo), codigo.codigo); // 6 números

    await _entraLuis(repo);
    expect(await repo.adultosACargo().first, isEmpty);

    final adulto = await repo.unirmeComoFamiliar(codigo.codigo, 'mamá');

    expect(adulto.folio, 'rosa');
    expect(adulto.parentesco, 'mamá');
    expect(adulto.idsCuidadores, ['ana', repo.uid]);
    // El celular de Rosa sigue siendo el suyo.
    expect(adulto.uidAdulto, 'rosa-cel');
    expect((await repo.adultosACargo().first).single.nombre, 'Rosa');
    final familia = await repo.familiaDe('rosa').first;
    expect(familia.map((f) => f.nombre), ['Ana', 'Luis']);
    expect(familia.last.telefono, '5500000003');
    expect(await repo.codigoUsado(codigo.codigo).first, isTrue);
  });

  test('La invitación solo sirve una vez', () async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await _entraLuis(repo);
    await repo.unirmeComoFamiliar(codigo.codigo, 'mamá');

    await repo.crearCuentaCuidador(
      nombre: 'Eva',
      apellidos: '',
      telefono: '5500000004',
      correo: 'eva@gmail.com',
      contrasena: 'secreto1',
    );
    expect(
      () => repo.unirmeComoFamiliar(codigo.codigo, 'tía'),
      _falla(errorCodigo),
    );
    expect(await repo.adultosACargo().first, isEmpty);
  });

  test('La invitación vence a las 24 horas', () async {
    var ahora = DateTime(2026, 11, 12, 9);
    repo = RepositorioMemoria(reloj: () => ahora);
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await _entraLuis(repo);
    ahora = ahora.add(const Duration(hours: 24, minutes: 1));

    expect(
      () => repo.unirmeComoFamiliar(codigo.codigo, 'mamá'),
      _falla(errorCodigo),
    );
  });

  test(
    'La invitación no entra por "Entrar con un código" del adulto',
    () async {
      final codigo = await repo.generarCodigo('rosa', familiar: true);
      await repo.cerrarSesion();

      expect(
        () => repo.canjearCodigo(codigo.codigo),
        _falla(errorCodigoFamiliar),
      );
      // Nadie le quitó su celular a Rosa y el código sigue sirviendo.
      expect(await repo.codigoUsado(codigo.codigo).first, isFalse);
    },
  );

  test('El código del adulto no sirve como invitación', () async {
    final codigo = await repo.generarCodigo('rosa');
    await _entraLuis(repo);

    expect(
      () => repo.unirmeComoFamiliar(codigo.codigo, 'mamá'),
      _falla(errorCodigoDelAdulto),
    );
    expect(await repo.adultosACargo().first, isEmpty);
    expect(await repo.codigoUsado(codigo.codigo).first, isFalse);
  });

  test('Quien ya la cuida no gasta la invitación', () async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);

    expect(
      () => repo.unirmeComoFamiliar(codigo.codigo, 'mamá'),
      _falla(errorYaLaCuidas),
    );
    expect(await repo.codigoUsado(codigo.codigo).first, isFalse);
  });

  test('Sin sesión no se puede canjear una invitación', () async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await repo.cerrarSesion();

    expect(
      () => repo.unirmeComoFamiliar(codigo.codigo, 'mamá'),
      _falla(errorCodigo),
    );
  });

  test('El mensaje de invitación dice cómo entrar', () {
    final texto = textoInvitacion('Rosa', '482913');
    expect(texto, contains('482 913'));
    expect(texto, contains('Me invitaron, tengo un código'));
    expect(texto, contains('24 horas'));
  });

  testWidgets('Familia y alertas da una invitación de 6 números que sí sirve', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Invitar a alguien con código'));
    await t.tap(find.text('Invitar a alguien con código'));
    await t.pumpAndSettle();

    expect(find.text('Código de invitación'), findsOneWidget);
    expect(find.textContaining('De prueba'), findsNothing);
    final visto = t
        .widget<SelectableText>(find.byType(SelectableText))
        .data!
        .replaceAll(' ', '');
    expect(normalizarCodigo(visto), visto);

    await _entraLuis(repo);
    final adulto = await repo.unirmeComoFamiliar(visto, 'mamá');
    expect(adulto.nombre, 'Rosa');
  });

  testWidgets('Luis crea su cuenta, toca "Me invitaron" y llega al panel', (
    t,
  ) async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await _entraLuis(repo);

    // Un cuidador sin nadie a cargo cae en AltaAdulto (ver destinoInicial).
    await t.pumpWidget(const MaterialApp(home: AltaAdulto()));
    await t.pumpAndSettle();
    await t.tap(find.text('Me invitaron, tengo un código'));
    await t.pumpAndSettle();
    expect(find.text('Escribe tu código de invitación'), findsOneWidget);

    await t.enterText(find.byType(TextField), codigo.codigo);
    await t.pump();
    // Sin parentesco no avanza y dice qué falta.
    await _bajarYTocar(t, 'Unirme');
    await t.pumpAndSettle();
    expect(find.text('Elige qué es tuyo'), findsOneWidget);

    await _bajarYTocar(t, 'mamá');
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Unirme');
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(PanelCuidador), findsOneWidget);
    expect(find.byType(AltaAdulto), findsNothing);
    expect((await repo.adultosACargo().first).single.nombre, 'Rosa');
  });

  testWidgets('Un código equivocado se explica en la pantalla', (t) async {
    final delAdulto = await repo.generarCodigo('rosa');
    await _entraLuis(repo);

    await t.pumpWidget(const MaterialApp(home: AltaAdulto()));
    await t.pumpAndSettle();
    await t.tap(find.text('Me invitaron, tengo un código'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), delAdulto.codigo);
    await t.pump();
    await _bajarYTocar(t, 'papá');
    await t.pumpAndSettle();
    await _bajarYTocar(t, 'Unirme');
    await t.pumpAndSettle();

    expect(find.text(errorCodigoDelAdulto), findsOneWidget);
  });
}
