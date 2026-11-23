import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/avisos.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/alerta.dart';
import 'package:nana_app/screens/aviso_ayuda.dart';
import 'package:nana_app/screens/panel_adulto.dart';

// Abre el aviso encima de otra pantalla, como lo hace el panel.
Future<void> _abrir(WidgetTester t, {bool porVoz = true}) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) =>
                    AvisoAyuda(folio: 'rosa', nombre: 'Rosa', porVoz: porVoz),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('abrir'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _esperar(WidgetTester t, int segundos) async {
  for (var i = 0; i < segundos * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late RepositorioMemoria repo;
  setUp(() {
    repo = RepositorioMemoria(sesion: 'rosa-cel');
    Servicios.repo = repo;
  });
  tearDown(() => Servicios.voz = VozNula());

  Future<List<Alerta>> alertas() => repo.alertasSinAtender('rosa').first;

  group('Lo que contesta', () {
    RespuestaAviso? c(String s) => entender(s, respuestasAviso);

    test('ante la duda, avisar', () {
      expect(c('no estoy bien'), RespuestaAviso.avisar);
      expect(c('no me puedo levantar'), RespuestaAviso.avisar);
      expect(c('sí, avísales'), RespuestaAviso.avisar);
      expect(c('ayúdame por favor'), RespuestaAviso.avisar);
    });

    test('cancelar', () {
      expect(c('estoy bien'), RespuestaAviso.cancelar);
      expect(c('ya estoy bien, no pasa nada'), RespuestaAviso.cancelar);
      expect(c('fue sin querer'), RespuestaAviso.cancelar);
    });

    test('un no a secas solo vuelve a preguntar', () {
      expect(c('no'), RespuestaAviso.no);
      expect(c('mmm'), isNull);
    });
  });

  group('Por voz', () {
    testWidgets('si no contesta, avisa sola como sin_respuesta', (t) async {
      final voz = VozNula();
      Servicios.voz = voz;
      await _abrir(t);
      expect(find.text('Voy a avisar a tu familia'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      await _esperar(t, 2);
      expect(voz.dicho, contains('Rosa, voy a avisarle a tu familia. Si estás bien, di: estoy bien.'));
      // Lo de antes se termina de cerrar DESPUÉS: no debe callar el aviso.
      expect(voz.callado, 0);

      await _esperar(t, 13);
      expect(await alertas(), isEmpty, reason: 'todavía no llega a cero');
      // A la mitad lo vuelve a decir.
      expect(voz.dicho, contains(startsWith('Si estás bien, di')));

      await _esperar(t, 6);
      final a = await alertas();
      expect(a, hasLength(1));
      expect(a.single.como, 'sin_respuesta');
      expect(find.text('Listo, ya le avisé a tu familia'), findsOneWidget);
    });

    testWidgets('«estoy bien» cancela y no avisa', (t) async {
      final voz = VozNula(respuestas: ['estoy bien']);
      Servicios.voz = voz;
      await _abrir(t);
      await _esperar(t, 2);

      expect(find.text('Voy a avisar a tu familia'), findsNothing);
      expect(find.text('No le avisé a nadie'), findsOneWidget);
      expect(voz.dicho, contains('Qué bueno que estás bien. Aquí sigo.'));
      await _esperar(t, 25);
      expect(await alertas(), isEmpty);
    });

    testWidgets('«sí» avisa de inmediato como voz', (t) async {
      Servicios.voz = VozNula(respuestas: ['sí']);
      await _abrir(t);
      await _esperar(t, 2);

      final a = await alertas();
      expect(a, hasLength(1));
      expect(a.single.como, 'voz');
    });

    testWidgets('«no» vuelve a preguntar y luego avisa', (t) async {
      final voz = VozNula(respuestas: ['no', 'avísales']);
      Servicios.voz = voz;
      await _abrir(t);
      await _esperar(t, 2);

      expect(voz.dicho, contains('¿Estás bien? Di: estoy bien. O di: avísales.'));
      expect((await alertas()).single.como, 'voz');
    });
  });

  group('Con el botón', () {
    testWidgets('«Ayuda» cuenta 5 s y avisa como botón', (t) async {
      await t.pumpWidget(const MaterialApp(home: PanelAdulto()));
      await t.pumpAndSettle();
      await t.tap(find.text('Ayuda'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Si fue sin querer, toca «Estoy bien»'), findsOneWidget);

      await _esperar(t, 6);
      expect((await alertas()).single.como, 'boton');
      expect(find.text('Listo, ya le avisé a tu familia'), findsOneWidget);
    });

    testWidgets('con el botón también lo dice en voz alta', (t) async {
      final voz = VozNula();
      Servicios.voz = voz;
      await _abrir(t, porVoz: false);
      await _esperar(t, 1);
      expect(
        voz.dicho,
        contains('Voy a avisarle a tu familia. Si fue sin querer, toca: estoy bien.'),
      );
    });

    testWidgets('«Estoy bien» deshace el toque', (t) async {
      await _abrir(t, porVoz: false);
      await t.tap(find.text('Estoy bien'));
      await _esperar(t, 7);
      expect(await alertas(), isEmpty);
    });

    testWidgets('«Avisar ya» no espera', (t) async {
      await _abrir(t, porVoz: false);
      await t.tap(find.text('Avisar ya'));
      await t.pump();
      expect((await alertas()).single.como, 'boton');
    });

    testWidgets('sin internet no dice que ya avisó', (t) async {
      repo.sinInternet = true;
      await _abrir(t, porVoz: false);
      await t.tap(find.text('Avisar ya'));
      await _esperar(t, 1);
      expect(find.text('No hay internet. Lo mando en cuanto haya'), findsOneWidget);
    });
  });

  group('Lo que ve la familia', () {
    final hora = DateTime(2026, 11, 21, 10, 5);

    test('«no contestó» sale primero', () {
      final l = ordenarAlertas([
        Alerta(id: 'a', fecha: hora.add(const Duration(minutes: 9))),
        Alerta(id: 'b', fecha: hora, como: 'sin_respuesta'),
        Alerta(id: 'c', fecha: hora, tipo: 'frase', texto: 'Me duele algo'),
      ]);
      expect(l.map((a) => a.id), ['b', 'a', 'c']);
    });

    test('la notificación dice cómo la pidió', () {
      final (t1, d1) = textoAviso('Rosa', Alerta(id: 'b', fecha: hora, como: 'sin_respuesta'));
      expect(t1, 'Rosa necesita ayuda y no contesta');
      expect(d1, contains('no contestó'));
      final (t2, d2) = textoAviso('Rosa', Alerta(id: 'a', fecha: hora, como: 'voz'));
      expect(t2, 'Rosa necesita ayuda');
      expect(d2, startsWith('Pidió ayuda con la voz'));
    });
  });
}
