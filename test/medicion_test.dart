import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/medicion.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/bienvenida.dart';
import 'package:nana_app/screens/como_va_la_prueba.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/widgets/formulario.dart';

void main() {
  late RepositorioMemoria repo;
  var ahora = DateTime(2026, 11, 14, 12);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    ahora = DateTime(2026, 11, 14, 12);
    Servicios.reloj = () => ahora;
    repo = RepositorioMemoria(reloj: Servicios.reloj);
    Servicios.repo = repo;
    Medicion.reiniciar();
    Medicion.reloj = () => ahora;
  });
  tearDown(Medicion.reiniciar);

  Widget app(Widget home) =>
      MaterialApp(navigatorObservers: [Medicion.observador], home: home);

  testWidgets('Apagado no anota nada', (t) async {
    await t.pumpWidget(app(const Bienvenida()));
    await t.pumpAndSettle();
    await t.tap(find.text('Soy cuidador o familiar'));
    await t.pumpAndSettle();
    Medicion.tarea('alta');
    Medicion.error();

    expect(Medicion.pendientes, isEmpty);
  });

  testWidgets('Anota la pantalla, cuánto duró y el regreso', (t) async {
    Medicion.activa = true;
    await t.pumpWidget(app(const Bienvenida()));
    await t.pumpAndSettle();
    ahora = ahora.add(const Duration(seconds: 8));
    await t.tap(find.text('Soy cuidador o familiar'));
    await t.pumpAndSettle();
    ahora = ahora.add(const Duration(seconds: 5));
    await t.pageBack();
    await t.pumpAndSettle();

    final e = Medicion.pendientes;
    expect(e.map((x) => '${x.tipo.name}:${x.pantalla}:${x.segundos}'), [
      'pantalla:Bienvenida:8',
      'pantalla:Soy cuidador o familiar:5',
      'regreso:Soy cuidador o familiar:0',
    ]);
  });

  testWidgets('Un mensaje de error se cuenta una vez y sin su texto', (
    t,
  ) async {
    Medicion.activa = true;
    await t.pumpWidget(app(const Bienvenida()));
    await t.pumpAndSettle();
    await t.pumpWidget(
      app(
        const Scaffold(
          body: MensajeError('El correo de ana@gmail.com ya tiene cuenta'),
        ),
      ),
    );
    await t.pump();
    await t.pump(); // volver a dibujar no lo cuenta otra vez

    final errores = Medicion.pendientes.where(
      (e) => e.tipo == TipoEvento.error,
    );
    expect(errores, hasLength(1));
    for (final e in Medicion.pendientes) {
      expect(e.aMapa().toString(), isNot(contains('ana@gmail.com')));
      expect(e.aMapa().keys, everyElement(isIn(['t', 'p', 's', 'f'])));
    }
  });

  test('Se manda por lotes y, si falla, se guarda para después', () async {
    Medicion.activa = true;
    var falla = true;
    final enviados = <EventoUso>[];
    Medicion.enviar = (lote) async {
      if (falla) throw Exception('sin internet');
      enviados.addAll(lote);
    };
    for (var i = 0; i < 15; i++) {
      Medicion.tarea('registro');
    }
    await Future<void>.delayed(Duration.zero);
    expect(enviados, isEmpty);
    expect(Medicion.pendientes, hasLength(15));

    falla = false;
    await Medicion.mandar();
    expect(enviados, hasLength(15));
    expect(Medicion.pendientes, isEmpty);
  });

  test('El resumen pone primero las pantallas donde más se atoran', () {
    EventoUso ev(TipoEvento t, String p, [int s = 0]) =>
        EventoUso(tipo: t, pantalla: p, segundos: s, fecha: ahora);
    final r = resumirUso([
      ev(TipoEvento.pantalla, 'Mi día', 20),
      ev(TipoEvento.pantalla, 'Mi día', 10),
      ev(TipoEvento.pantalla, 'Alta de la persona', 60),
      ev(TipoEvento.regreso, 'Alta de la persona'),
      ev(TipoEvento.error, 'Alta de la persona'),
      ev(TipoEvento.pantalla, 'Hoja', 3),
      ev(TipoEvento.tarea, 'alta'),
      ev(TipoEvento.tarea, 'alta'),
    ]);

    expect(r.pantallas.map((p) => p.pantalla), [
      'Alta de la persona',
      'Mi día',
    ]);
    expect(r.pantallas.first.regresos, 1);
    expect(r.pantallas.first.errores, 1);
    expect(r.pantallas.last.promedio, 15);
    expect(r.tareas, {'alta': 2});
  });

  test('Un evento va y regresa del mapa que se guarda', () {
    final e = EventoUso(
      tipo: TipoEvento.pantalla,
      pantalla: 'Mi día',
      segundos: 12,
      fecha: ahora,
    );
    final otro = EventoUso.deMapa(e.aMapa())!;
    expect(otro.tipo, TipoEvento.pantalla);
    expect(otro.pantalla, 'Mi día');
    expect(otro.segundos, 12);
    expect(otro.fecha, ahora);
    expect(EventoUso.deMapa({'t': 'raro', 'p': 'x', 'f': 1}), isNull);
  });

  group('Permiso del encargado', () {
    test('Solo el principal prende el estudio', () async {
      expect((await repo.adultosACargo().first).single.estudio, isFalse);
      await repo.guardarEstudio('rosa', true);
      expect((await repo.adultosACargo().first).single.estudio, isTrue);

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
        () => repo.guardarEstudio('rosa', false),
        throwsA(isA<ErrorNana>()),
      );
    });

    testWidgets('El interruptor está en Familia y alertas', (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        const MaterialApp(
          home: FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Ayudar a mejorar NANA'), findsOneWidget);
      final interruptor = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Ayudar a mejorar NANA',
      );
      await t.tap(
        find.descendant(of: interruptor, matching: find.byType(Switch)),
      );
      await t.pumpAndSettle();
      expect((await repo.adultosACargo().first).single.estudio, isTrue);
    });
  });

  group('Cómo va la prueba', () {
    testWidgets('Quien no es del equipo no la puede leer', (t) async {
      await t.pumpWidget(const MaterialApp(home: ComoVaLaPrueba()));
      await t.pumpAndSettle();
      expect(find.text(errorSinPermiso), findsOneWidget);
    });

    testWidgets('El equipo ve dónde se atoran y las tareas hechas', (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      repo.adminEstudio = true;
      EventoUso ev(TipoEvento tipo, String p, [int s = 0]) =>
          EventoUso(tipo: tipo, pantalla: p, segundos: s, fecha: ahora);
      await repo.guardarUso([
        ev(TipoEvento.pantalla, 'Alta de la persona', 90),
        ev(TipoEvento.regreso, 'Alta de la persona'),
        ev(TipoEvento.pantalla, 'Mi día', 12),
        ev(TipoEvento.tarea, 'pidio_ayuda'),
      ], rol: 'cuidador');

      await t.pumpWidget(const MaterialApp(home: ComoVaLaPrueba()));
      await t.pumpAndSettle();

      expect(find.text('Alta de la persona'), findsOneWidget);
      expect(find.textContaining('1 regresos'), findsOneWidget);
      expect(find.text('Pedir ayuda (adulto)'), findsOneWidget);
      expect(find.text('1 vez'), findsOneWidget);
    });
  });
}
