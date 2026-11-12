import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/senas/catalogo.dart';
import 'package:nana_app/core/senas/clasificador.dart';
import 'package:nana_app/core/senas/ojo.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/screens/senas.dart';

// Una mano de mentira: 21 puntos en fila, con los dedos abiertos según [abre]
// para que dos "señas" queden bien distintas.
List<Punto> _mano(
  double abre, {
  double dx = 0,
  double dy = 0,
  double tam = 1,
}) => [
  for (var i = 0; i < puntosPorMano; i++)
    (
      x: dx + tam * (i % 4) * abre,
      y: dy - tam * (i ~/ 4) * 10.0,
      z: tam * i * 0.1,
    ),
];

final _punio = normalizarMano(_mano(0.5));
final _abierta = normalizarMano(_mano(8));

List<EjemploSena> _ejemplos() => [
  for (var i = 0; i < 6; i++) ...[
    EjemploSena('dolor', normalizarMano(_mano(0.5 + i * 0.05))),
    EjemploSena('ayuda', normalizarMano(_mano(8 + i * 0.1))),
  ],
];

// La cámara de mentira: la prueba le dice qué mano "ve".
class _OjoFalso implements OjoSenas {
  final String? error;
  _OjoFalso({this.error});
  final control = StreamController<ManoVista?>.broadcast();
  bool cerrado = false;

  @override
  Future<String?> abrir() async => error;
  @override
  Stream<ManoVista?> get manos => control.stream;
  @override
  Widget vista() => const SizedBox.expand();
  @override
  Future<void> cerrar() async => cerrado = true;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Reconocer señas', () {
    test('La misma mano más lejos o en otro lugar es la misma seña', () {
      final cerca = normalizarMano(_mano(8));
      final lejos = normalizarMano(_mano(8, dx: 300, dy: 120, tam: 0.4));
      for (var i = 0; i < cerca.length; i++) {
        expect(lejos[i], closeTo(cerca[i], 1e-9));
      }
    });

    test('La mano izquierda vale igual que la derecha (espejo)', () {
      final derecha = normalizarMano(_mano(8));
      final izquierda = normalizarMano([
        for (final p in _mano(8)) (x: -p.x, y: p.y, z: p.z),
      ], izquierda: true);
      for (var i = 0; i < derecha.length; i++) {
        expect(izquierda[i], closeTo(derecha[i], 1e-9));
      }
    });

    test('Gana la seña que más se parece', () {
      final c = ClasificadorSenas(_ejemplos());
      expect(c.clasificar(_punio), 'dolor');
      expect(c.clasificar(_abierta), 'ayuda');
    });

    test('Si no se parece a nada, no adivina', () {
      final c = ClasificadorSenas(_ejemplos(), distanciaMaxima: 0.2);
      expect(c.clasificar(normalizarMano(_mano(3.5))), isNull);
      expect(const ClasificadorSenas([]).clasificar(_punio), isNull);
    });

    test('Los ejemplos se guardan y se leen como texto', () {
      final ida = ejemplosAJson(_ejemplos());
      final vuelta = ejemplosDeJson(ida);
      expect(vuelta, hasLength(12));
      expect(ClasificadorSenas(vuelta).clasificar(_abierta), 'ayuda');
      expect(ejemplosDeJson(''), isEmpty);
    });

    test('Una seña solo cuenta si se sostiene, y cuenta una sola vez', () {
      final s = SenaSostenida();
      final t0 = DateTime(2026, 11, 12, 10);
      DateTime en(int ms) => t0.add(Duration(milliseconds: ms));
      expect(s.ver('dolor', en(0)), isNull);
      expect(s.ver('dolor', en(500)), isNull);
      // Cambió de seña a medio camino: empieza de nuevo.
      expect(s.ver('ayuda', en(600)), isNull);
      expect(s.ver('ayuda', en(1400)), isNull);
      expect(s.ver('ayuda', en(1500)), 'ayuda');
      expect(s.ver('ayuda', en(3000)), isNull);
      // Bajó la mano y la volvió a hacer.
      expect(s.ver(null, en(3100)), isNull);
      expect(s.ver('ayuda', en(3200)), isNull);
      expect(s.ver('ayuda', en(4200)), 'ayuda');
    });

    // Una mano con los cuatro dedos doblados y el pulgar hacia [dy].
    List<double> conPulgar(double dy) {
      final p = [
        for (var i = 0; i < puntosPorMano; i++) (x: 0.0, y: 0.0, z: 0.0),
      ];
      // nudillos medios lejos de la muñeca, puntas más cerca (dobladas)
      for (final (punta, medio, x) in [
        (8, 6, 10.0),
        (12, 10, 20.0),
        (16, 14, 30.0),
        (20, 18, 40.0),
      ]) {
        p[medio] = (x: x + 40, y: 0, z: 0);
        p[medio - 1] = (x: x + 20, y: 5, z: 0);
        p[punta - 1] = (x: x + 30, y: 8, z: 0);
        p[punta] = (x: x + 15, y: 10, z: 0);
      }
      p[1] = (x: 10, y: dy * 0.3, z: 0);
      p[2] = (x: 15, y: dy * 0.5, z: 0);
      p[3] = (x: 18, y: dy * 0.8, z: 0);
      p[4] = (x: 20, y: dy, z: 0);
      return normalizarMano(p);
    }

    test('Pulgar arriba es sí, pulgar abajo es no', () {
      // En la imagen "arriba" es y negativa.
      expect(pulgarDe(conPulgar(-70)), Pulgar.arriba);
      expect(pulgarDe(conPulgar(70)), Pulgar.abajo);
      // Pulgar de lado: ni sí ni no.
      expect(pulgarDe(conPulgar(4)), isNull);
      // Mano abierta (dedos estirados): tampoco.
      expect(pulgarDe(_abierta), isNull);
    });

    test('Al grabar una seña se guarda también en espejo', () async {
      SharedPreferences.setMockInitialValues({});
      final almacen = AlmacenSenas();
      await almacen.cargar();
      await almacen.agregar(EjemploSena('dolor', _punio));
      expect(almacen.deEsteCelular, hasLength(2));
      expect(almacen.deEsteCelular[1].mano, espejoDe(_punio));
      await almacen.borrar('dolor');
      expect(almacen.deEsteCelular, isEmpty);
    });

    test('Cada seña del catálogo tiene su frase', () {
      expect(fraseDeSena('dolor'), 'Me duele algo');
      expect(fraseDeSena('no-existe'), isNull);
      expect(senasNana.map((s) => s.id).toSet(), hasLength(senasNana.length));
    });
  });

  group('La pantalla de la cámara', () {
    late _OjoFalso ojo;
    late VozNula voz;
    late DateTime ahora;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'senas_ejemplos': ejemplosAJson(_ejemplos()),
      });
      ojo = _OjoFalso();
      voz = VozNula();
      ahora = DateTime(2026, 11, 12, 10);
      Servicios.crearOjo = () => ojo;
      Servicios.voz = voz;
      // Se leen aquí: dentro de la prueba el disco no avanza solo.
      Servicios.senas = AlmacenSenas();
      await Servicios.senas.cargar();
      Servicios.reloj = () => ahora;
      addTearDown(() {
        Servicios.crearOjo = OjoSinCamara.new;
        Servicios.voz = VozNula();
        Servicios.reloj = DateTime.now;
      });
    });

    Future<List<String?>> abrir(WidgetTester t) async {
      final dicho = <String?>[];
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => dicho.add(
                await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const CamaraSenas()),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      return dicho;
    }

    // La cámara "ve" esa mano durante un rato.
    Future<void> sostener(WidgetTester t, ManoVista? m) async {
      for (var i = 0; i < 4; i++) {
        ojo.control.add(m);
        await t.pump();
        ahora = ahora.add(const Duration(milliseconds: 400));
      }
    }

    testWidgets('Hace la seña, NANA pregunta y el pulgar arriba confirma', (
      t,
    ) async {
      final dicho = await abrir(t);
      expect(find.text('Cámara encendida'), findsOneWidget);

      await sostener(t, ManoVista(_punio));
      expect(find.text('Me duele algo'), findsOneWidget);
      expect(voz.dicho, contains('¿Quisiste decir: Me duele algo?'));
      expect(dicho, isEmpty); // todavía no se manda nada

      await sostener(t, null);
      await sostener(
        t,
        ManoVista(_abierta.map((v) => v + 9).toList(), pulgarArriba: true),
      );
      await t.pumpAndSettle();
      expect(dicho, ['Me duele algo']);
      expect(ojo.cerrado, isTrue);
    });

    testWidgets('Con el pulgar abajo NANA no manda nada y deja repetir', (
      t,
    ) async {
      final dicho = await abrir(t);
      await sostener(t, ManoVista(_abierta));
      expect(find.text('Necesito ayuda'), findsOneWidget);

      await sostener(t, null);
      await sostener(
        t,
        ManoVista(_abierta.map((v) => v + 9).toList(), pulgarAbajo: true),
      );
      expect(find.text('¿Quisiste decir?'), findsNothing);
      expect(dicho, isEmpty);
    });

    testWidgets('Un pulgar arriba suelto no dice nada', (t) async {
      final dicho = await abrir(t);
      await sostener(
        t,
        ManoVista(_abierta.map((v) => v + 9).toList(), pulgarArriba: true),
      );
      expect(find.text('¿Quisiste decir?'), findsNothing);
      expect(dicho, isEmpty);
    });

    testWidgets('Apagar cámara la apaga y no manda nada', (t) async {
      final dicho = await abrir(t);
      await t.tap(find.text('Apagar cámara'));
      await t.pumpAndSettle();
      expect(dicho, [null]);
      expect(ojo.cerrado, isTrue);
    });

    testWidgets('Si no hay permiso lo dice y ofrece las frases', (t) async {
      ojo = _OjoFalso(error: 'No diste permiso de usar la cámara');
      await abrir(t);
      expect(find.text('No diste permiso de usar la cámara'), findsOneWidget);
      expect(find.text('Cámara apagada'), findsOneWidget);
      expect(voz.dicho, contains('No diste permiso de usar la cámara'));
    });
  });
}
