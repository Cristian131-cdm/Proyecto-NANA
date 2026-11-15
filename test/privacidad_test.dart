import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/fotos_locales.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/screens/alta_adulto.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/pestana_historial.dart';

// Un PNG de 1x1 para hacer de "foto de la receta".
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

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
  await t.pumpAndSettle();
}

void main() {
  late RepositorioMemoria repo;
  late FotosEnMemoria fotos;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    Servicios.reloj = () => DateTime(2026, 11, 14, 12);
    repo = RepositorioMemoria(reloj: Servicios.reloj);
    Servicios.repo = repo;
    fotos = FotosEnMemoria();
    Servicios.fotos = fotos;
  });
  tearDown(() => Servicios.fotos = const SinFotos());

  group('Permiso para guardar datos', () {
    test('Al dar de alta queda anotado quién aceptó y cuándo', () async {
      final folio = await repo.altaAdulto(
        nombre: 'Ernesto',
        apellidos: '',
        parentesco: 'papá',
        tieneCelular: false,
      );
      final adulto = (await repo.adultosACargo().first).firstWhere(
        (a) => a.folio == folio,
      );
      expect(adulto.creadoPor, 'ana');
      expect(adulto.consentimiento, DateTime(2026, 11, 14, 12));
    });

    testWidgets('Sin palomear el permiso no se puede dar de alta', (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const MaterialApp(home: AltaAdulto()));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ernesto');
      await _bajarYTocar(t, 'papá');
      await _bajarYTocar(t, 'Siguiente');

      expect(find.text('Antes de guardar sus datos'), findsOneWidget);
      expect(find.textContaining('nunca sube documentos'), findsOneWidget);
      final boton = t.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuar'),
      );
      expect(boton.onPressed, isNull);
      // Todavía no se guardó nada de Ernesto.
      expect(await repo.adultosACargo().first, hasLength(1));

      await _bajarYTocar(t, 'Estoy de acuerdo y Ernesto también lo sabe');
      await _bajarYTocar(t, 'Continuar');
      expect(find.text('¿Ernesto tiene celular propio?'), findsOneWidget);
    });
  });

  group('Foto de la receta', () {
    testWidgets('Se queda en el celular y al repositorio solo va el texto', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      fotos.siguiente = Uint8List.fromList(_png);
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PestanaHistorial(adulto: 'Rosa', folio: 'rosa'),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _bajarYTocar(t, 'Agregar receta');
      await t.enterText(find.byType(TextField).at(0), 'Dra. Ruiz');
      await t.enterText(find.byType(TextField).at(1), 'Omeprazol 20 mg');
      expect(find.text(avisoFotoLocal), findsOneWidget);
      await _bajarYTocar(t, 'Agregar foto (opcional)');
      expect(find.text('Foto agregada'), findsOneWidget);
      await _bajarYTocar(t, 'Guardar');

      final receta = (await repo.recetas('rosa').first).firstWhere(
        (r) => r.medico == 'Dra. Ruiz',
      );
      expect(receta.indicacion, 'Omeprazol 20 mg');
      // La foto existe solo en el almacén del celular, ligada por el id.
      expect(fotos.guardadas.keys, [receta.id]);

      await t.runAsync(() async {
        await repo.borrarReceta('rosa', receta.id!);
      });
    });

    testWidgets('En la web (sin almacén) no se ofrece agregar foto', (t) async {
      Servicios.fotos = const SinFotos();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FormularioReceta(onGuardar: (_, _) {})),
        ),
      );
      expect(find.text('Agregar foto (opcional)'), findsNothing);
    });
  });

  group('Borrar todos los datos', () {
    test('Quien dio de alta borra todo lo de la persona', () async {
      await repo.guardarMedicamento(
        'rosa',
        const Medicamento(
          nombre: 'Metformina',
          dosis: '850 mg',
          hora: TimeOfDay(hour: 9, minute: 0),
          ventanaMin: 30,
        ),
      );
      await repo.pedirAyuda('rosa');
      final codigo = await repo.generarCodigo('rosa', familiar: true);

      await repo.borrarAdulto('rosa');

      expect(await repo.adultosACargo().first, isEmpty);
      expect(await repo.medicamentos('rosa').first, isEmpty);
      expect(await repo.recetas('rosa').first, isEmpty);
      expect(await repo.rutinas('rosa').first, isEmpty);
      expect(await repo.alertasSinAtender('rosa').first, isEmpty);
      expect(await repo.familiaDe('rosa').first, isEmpty);
      // Una invitación que quedó pendiente ya no sirve.
      expect(
        () => repo.revisarInvitacion(codigo.codigo),
        throwsA(isA<ErrorNana>()),
      );
    });

    test('Un familiar invitado no puede borrar', () async {
      final codigo = await repo.generarCodigo('rosa', familiar: true);
      await repo.crearCuentaCuidador(
        nombre: 'Luis',
        apellidos: '',
        telefono: '5500000003',
        correo: 'luis@gmail.com',
        contrasena: 'secreto1',
      );
      await repo.unirmeComoFamiliar(codigo.codigo, 'mamá');

      expect(
        () => repo.borrarAdulto('rosa'),
        throwsA(
          isA<ErrorNana>().having(
            (e) => e.mensaje,
            'mensaje',
            errorSoloEncargado,
          ),
        ),
      );
      expect(await repo.adultosACargo().first, hasLength(1));
    });

    testWidgets('El botón solo le sale al encargado y pide confirmar', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      // Luis entró con una invitación: es familiar, no encargado.
      final codigo = await repo.generarCodigo('rosa', familiar: true);
      await repo.crearCuentaCuidador(
        nombre: 'Luis',
        apellidos: '',
        telefono: '5500000003',
        correo: 'luis@gmail.com',
        contrasena: 'secreto1',
      );
      await repo.unirmeComoFamiliar(codigo.codigo, 'mamá');
      await t.pumpWidget(
        const MaterialApp(
          home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Borrar todos los datos de Rosa'), findsNothing);

      // Ana la dio de alta: a ella sí le sale.
      await repo.iniciarSesion('ana@nana.mx', 'secreto1');
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        const MaterialApp(
          home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
        ),
      );
      await t.pumpAndSettle();
      await _bajarYTocar(t, 'Borrar todos los datos de Rosa');
      expect(find.text('¿Borrar todo lo de Rosa?'), findsOneWidget);

      // "No, conservar" no borra nada.
      await t.tap(find.text('No, conservar'));
      await t.pumpAndSettle();
      expect(await repo.adultosACargo().first, hasLength(1));

      await _bajarYTocar(t, 'Borrar todos los datos de Rosa');
      await t.tap(find.text('Sí, borrar todo'));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(await repo.adultosACargo().first, isEmpty);
      // Sin nadie a cargo, el encargado cae en dar de alta.
      expect(find.byType(AltaAdulto), findsOneWidget);
    });
  });

  testWidgets('"Tus datos" dice que los documentos no se suben', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: PantallaPrivacidad()));
    expect(find.text('Tus documentos no se suben'), findsOneWidget);
    expect(find.text('Borrar los datos'), findsOneWidget);
  });
}
