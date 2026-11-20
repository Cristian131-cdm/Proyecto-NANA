import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/perfil_accesibilidad.dart';
import 'package:nana_app/core/permisos.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/adulto.dart';
import 'package:nana_app/models/apariencia.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/panel_cuidador.dart';
import 'package:nana_app/screens/pantalla_del_adulto.dart';

Matcher _falla(String mensaje) =>
    throwsA(isA<ErrorNana>().having((e) => e.mensaje, 'mensaje', mensaje));

void main() {
  late RepositorioMemoria repo;
  var ahora = DateTime(2026, 11, 14, 12);
  late String luis;

  // Ana dio de alta a Rosa (principal). Luis entra con una invitación.
  Future<void> entraLuis() async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await repo.crearCuentaCuidador(
      nombre: 'Luis',
      apellidos: '',
      telefono: '5500000003',
      correo: 'luis@gmail.com',
      contrasena: 'secreto1',
    );
    await repo.unirmeComoFamiliar(codigo.codigo, 'mamá');
    luis = repo.uid!;
  }

  Future<void> comoAna() => repo.iniciarSesion('ana@nana.mx', 'secreto1');
  Future<void> comoLuis() => repo.iniciarSesion('luis@gmail.com', 'secreto1');
  Future<Adulto> rosa() async => (await repo.adultosACargo().first).single;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    ahora = DateTime(2026, 11, 14, 12);
    Servicios.reloj = () => ahora;
    repo = RepositorioMemoria(reloj: Servicios.reloj);
    Servicios.repo = repo;
  });

  group('Papeles', () {
    test('Quien da de alta es el principal; el invitado es familiar', () async {
      await entraLuis();
      expect(rolDe(await rosa(), luis, ahora), RolCuidador.familiar);
      await comoAna();
      expect(rolDe(await rosa(), 'ana', ahora), RolCuidador.principal);
    });

    test('Cada papel puede lo que le toca', () {
      const principal = Permisos(RolCuidador.principal);
      const suplente = Permisos(RolCuidador.suplente);
      const familiar = Permisos(RolCuidador.familiar);

      expect(principal.invitar && principal.borrarDatos, isTrue);
      expect(principal.editarSalud && principal.pantallaDelAdulto, isTrue);

      expect(suplente.editarMedicinasYRutinas, isTrue);
      expect(suplente.verSalud, isTrue);
      expect(suplente.codigoDelAdulto, isTrue);
      expect(suplente.editarSalud, isFalse);
      expect(suplente.invitar, isFalse);
      expect(suplente.cambiarAlertas, isFalse);
      expect(suplente.borrarDatos, isFalse);
      expect(suplente.nombrarSuplente, isFalse);

      expect(familiar.editarMedicinasYRutinas, isFalse);
      expect(familiar.verSalud, isFalse);
      expect(familiar.codigoDelAdulto, isFalse);
      expect(familiar.invitar, isFalse);
    });
  });

  group('Suplente', () {
    test('Con fecha: vale hasta ese día y después se quita solo', () async {
      await entraLuis();
      await comoAna();
      final hasta = DateTime(2026, 11, 20, 23, 59);
      await repo.nombrarSuplente('rosa', luis, hasta: hasta);

      var a = await rosa();
      expect(rolDe(a, luis, ahora), RolCuidador.suplente);
      expect(vigenciaSuplente(a.suplente!), 'hasta el 20 de noviembre de 2026');

      ahora = DateTime(2026, 11, 21, 0, 5);
      a = await rosa();
      expect(rolDe(a, luis, ahora), RolCuidador.familiar);
    });

    test('Sin fecha de fin: dura hasta que el principal lo quita', () async {
      await entraLuis();
      await comoAna();
      await repo.nombrarSuplente('rosa', luis);

      ahora = ahora.add(const Duration(days: 400));
      var a = await rosa();
      expect(rolDe(a, luis, ahora), RolCuidador.suplente);
      expect(vigenciaSuplente(a.suplente!), 'sin fecha de fin');

      await repo.quitarSuplente('rosa');
      a = await rosa();
      expect(a.suplente, isNull);
      expect(rolDe(a, luis, ahora), RolCuidador.familiar);
    });

    test(
      'Solo el principal nombra suplente, y solo a alguien de la familia',
      () async {
        await entraLuis();
        // Luis no puede nombrarse a sí mismo.
        expect(
          () => repo.nombrarSuplente('rosa', luis),
          _falla(errorSinPermiso),
        );

        await comoAna();
        expect(
          () => repo.nombrarSuplente('rosa', 'ana'),
          throwsA(isA<ErrorNana>()),
        );
        expect(
          () => repo.nombrarSuplente('rosa', 'alguien-de-fuera'),
          throwsA(isA<ErrorNana>()),
        );
        expect(
          () => repo.nombrarSuplente(
            'rosa',
            luis,
            hasta: ahora.subtract(const Duration(days: 1)),
          ),
          throwsA(isA<ErrorNana>()),
        );
      },
    );

    test('El suplente saca el código del adulto, pero no invita', () async {
      await entraLuis();
      // Como familiar no puede ninguno de los dos.
      expect(() => repo.generarCodigo('rosa'), _falla(errorSinPermiso));
      expect(
        () => repo.generarCodigo('rosa', familiar: true),
        _falla(errorSinPermiso),
      );

      await comoAna();
      await repo.nombrarSuplente('rosa', luis);
      await comoLuis();
      expect((await repo.generarCodigo('rosa')).familiar, isFalse);
      expect(
        () => repo.generarCodigo('rosa', familiar: true),
        _falla(errorSinPermiso),
      );
    });
  });

  group('Quitar a alguien de la familia', () {
    test('El principal quita a un familiar (y su suplencia)', () async {
      await entraLuis();
      await comoAna();
      await repo.nombrarSuplente('rosa', luis);

      await repo.quitarFamiliar('rosa', luis);

      final a = await rosa();
      expect(a.idsCuidadores, ['ana']);
      expect(a.suplente, isNull);
      await comoLuis();
      expect(await repo.adultosACargo().first, isEmpty);
    });

    test('Nadie quita al principal y un familiar no quita a nadie', () async {
      await entraLuis();
      expect(() => repo.quitarFamiliar('rosa', 'ana'), _falla(errorSinPermiso));
      await comoAna();
      expect(
        () => repo.quitarFamiliar('rosa', 'ana'),
        throwsA(isA<ErrorNana>()),
      );
      expect((await rosa()).idsCuidadores, ['ana', luis]);
    });
  });

  group('Pantalla del adulto', () {
    test('Solo el principal la cambia', () async {
      await entraLuis();
      expect(
        () =>
            repo.guardarApariencia('rosa', const Apariencia(escalaTexto: 1.5)),
        _falla(errorSinPermiso),
      );
      await comoAna();
      await repo.guardarApariencia('rosa', const Apariencia(escalaTexto: 1.5));
      expect((await repo.apariencia('rosa').first)?.escalaTexto, 1.5);
    });

    test('El celular la aplica una vez y respeta lo que la persona cambie', () {
      final a = Apariencia(
        escalaTexto: 1.5,
        altoContraste: true,
        queMeHable: true,
        actualizado: DateTime(2026, 11, 14, 12),
      );
      aplicarApariencia(a);
      expect(Ajustes.escalaTexto.value, 1.5);
      expect(Ajustes.altoContraste.value, isTrue);
      expect(Ajustes.queMeHable.value, isTrue);

      // La persona baja la letra en "Aa": la misma orden no se vuelve a aplicar.
      Ajustes.escalaTexto.value = 1.0;
      aplicarApariencia(a);
      expect(Ajustes.escalaTexto.value, 1.0);

      // El encargado manda un cambio nuevo: ese sí se aplica.
      aplicarApariencia(
        a.copyWith(escalaTexto: 1.25, actualizado: DateTime(2026, 11, 15)),
      );
      expect(Ajustes.escalaTexto.value, 1.25);

      // Sin nada mandado no se toca nada.
      aplicarApariencia(null);
      expect(Ajustes.escalaTexto.value, 1.25);
    });

    testWidgets('El encargado elige letra muy grande y se guarda', (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        const MaterialApp(
          home: PantallaDelAdulto(adulto: 'Rosa', folio: 'rosa'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Muy grande'));
      await t.tap(find.text('Que le hable'));
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();

      final guardada = await repo.apariencia('rosa').first;
      expect(guardada?.escalaTexto, 1.5);
      expect(guardada?.queMeHable, isTrue);
      expect(guardada?.actualizado, isNotNull);
    });
  });

  group('Lo que ve cada quien', () {
    Future<void> abrirFamilia(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(800, 2600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        const MaterialApp(
          home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('El principal ve todo lo de administrar', (t) async {
      await entraLuis();
      await comoAna();
      await abrirFamilia(t);

      expect(find.text('Invitar a alguien con código'), findsOneWidget);
      expect(find.text('Pantalla de Rosa'), findsOneWidget);
      expect(find.text('Borrar todos los datos de Rosa'), findsOneWidget);
      expect(find.textContaining('Encargado principal'), findsOneWidget);
      expect(find.textContaining('Familiar'), findsOneWidget);
      final interruptores = t.widgetList<Switch>(find.byType(Switch)).toList();
      expect(interruptores.first.onChanged, isNotNull);
    });

    testWidgets('El principal deja a Luis de suplente sin fecha de fin', (
      t,
    ) async {
      await entraLuis();
      await comoAna();
      await abrirFamilia(t);

      await t.tap(find.text('Luis'));
      await t.pumpAndSettle();
      await t.tap(find.text('Dejar como suplente'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sin fecha de fin'));
      await t.pumpAndSettle();

      expect((await rosa()).suplente?.uid, luis);
      expect(find.text('Suplente activo: Luis'), findsOneWidget);
      expect(find.text('Sin fecha de fin'), findsOneWidget);
    });

    testWidgets('El familiar no ve nada de administrar', (t) async {
      await entraLuis();
      await abrirFamilia(t);

      expect(find.text('Invitar a alguien con código'), findsNothing);
      expect(find.text('Pantalla de Rosa'), findsNothing);
      expect(find.text('Borrar todos los datos de Rosa'), findsNothing);
      // Las reglas de alerta se ven, pero apagadas para él.
      final interruptores = t.widgetList<Switch>(find.byType(Switch)).toList();
      expect(interruptores.every((s) => s.onChanged == null), isTrue);

      await t.tap(find.text('Ana'));
      await t.pumpAndSettle();
      expect(find.text('Dejar como suplente'), findsNothing);
      expect(find.text('Quitar de la familia'), findsNothing);
    });

    testWidgets(
      'En su panel, el familiar no puede agregar ni ver el expediente',
      (t) async {
        // Alto para que la pestaña Más se dibuje completa.
        await t.binding.setSurfaceSize(const Size(800, 1800));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await entraLuis();
        await t.pumpWidget(const MaterialApp(home: PanelCuidador()));
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Eres familiar'), findsOneWidget);

        await t.tap(find.text('Medicinas').last);
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(find.textContaining('Losartán'), findsWidgets);
        expect(find.text('Agregar medicina'), findsNothing);
        expect(find.byTooltip('Borrar Losartán'), findsNothing);
        expect(find.text('Las agrega y cambia Ana.'), findsOneWidget);

        await t.tap(find.text('Más').last);
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        // El familiar no ve «Pantalla de Rosa» ni la entrada del expediente.
        expect(find.text('Pantalla de Rosa'), findsNothing);
        expect(find.text('Su expediente'), findsNothing);
        expect(find.text('Quién más la cuida'), findsOneWidget);
        expect(find.text('Solo ver'), findsOneWidget);
        expect(find.text('Mis alertas'), findsOneWidget);
        expect(find.text('Dejar de acompañar a Rosa'), findsOneWidget);
        // El familiar no da códigos: no ve esa sección.
        expect(find.text('Códigos'), findsNothing);
      },
    );

    testWidgets('El principal sí puede agregar medicinas', (t) async {
      await t.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const MaterialApp(home: PanelCuidador()));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Eres familiar'), findsNothing);
      await t.tap(find.text('Medicinas').last);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Agregar medicina'), findsWidgets);
      expect(find.text('Las agrega y cambia Ana.'), findsNothing);

      await t.tap(find.text('Más').last);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Su expediente'), findsOneWidget);
      expect(find.text('Familia y alertas'), findsOneWidget);
      expect(find.text('Dejar de acompañar a Rosa'), findsNothing);
    });
  });
}
