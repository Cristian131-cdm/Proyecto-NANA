import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/despertador.dart';
import 'package:nana_app/core/platica.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/alerta.dart';
import 'package:nana_app/models/apariencia.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/registro.dart';
import 'package:nana_app/screens/platica_nana.dart';
import 'package:nana_app/widgets/espera_oye_nana.dart';
import 'package:nana_app/core/perfil_accesibilidad.dart';

// Martes 18 de noviembre de 2026, 3:00 pm.
final _ahora = DateTime(2026, 11, 18, 15);

RespuestaPlatica _adulto(String oido) => respuestaAdulto(
  oido,
  nombre: 'Rosa',
  queSigue: () => 'Lo que sigue: Caminar, a las 6:00 pm.',
  ahora: _ahora,
);

const _losartan = Medicamento(
  id: 'los',
  nombre: 'Losartán',
  dosis: '50 mg',
  hora: TimeOfDay(hour: 8, minute: 0),
  ventanaMin: 30,
);
const _metformina = Medicamento(
  id: 'met',
  nombre: 'Metformina',
  dosis: '850 mg',
  hora: TimeOfDay(hour: 20, minute: 0),
  ventanaMin: 30,
);

Registro _reg(
  TipoActividad tipo,
  String titulo,
  DateTime f, {
  String? med,
  int? valor,
}) => Registro(
  tipo: tipo,
  titulo: titulo,
  idMedicamento: med,
  valor: valor,
  fecha: f,
  registradoPor: 'rosa',
);

DatosEncargado _datos({List<Registro>? hoy, List<Alerta> alertas = const []}) {
  final deHoy =
      hoy ??
      [
        _reg(
          TipoActividad.medicina,
          'Losartán 50 mg',
          DateTime(2026, 11, 18, 8, 10),
          med: 'los',
        ),
        _reg(TipoActividad.animo, 'Bien', DateTime(2026, 11, 18, 9), valor: 1),
      ];
  return DatosEncargado(
    nombre: 'Rosa',
    meds: const [_losartan, _metformina],
    rutinas: const [],
    hoy: deHoy,
    semana: [
      ...deHoy,
      _reg(
        TipoActividad.medicina,
        'Losartán 50 mg',
        DateTime(2026, 11, 17, 8, 5),
        med: 'los',
      ),
      _reg(
        TipoActividad.medicina,
        'Metformina 850 mg',
        DateTime(2026, 11, 17, 20, 5),
        med: 'met',
      ),
      _reg(TipoActividad.animo, 'Mal', DateTime(2026, 11, 16, 10), valor: 3),
    ],
    alertas: alertas,
    ahora: _ahora,
  );
}

// Lo que dice el adulto nunca debe sonar a consejo médico.
final _consejo = RegExp(
  r'\b(\d+ ?mg|tómate|toma una|dosis de|te recomiendo)\b',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('«Oye NANA»', () {
    test('reconoce la frase y lo que el celular suele oír mal', () {
      for (final f in [
        'Oye NANA',
        'oye, Nana',
        '¡Hola Nana!',
        'oye Ana',
        'Oye nena ¿qué hora es?',
      ]) {
        expect(esDespertar(f), isTrue, reason: f);
      }
      for (final f in ['nana', 'banana', 'mañana voy', 'oye', null]) {
        expect(esDespertar(f), isFalse, reason: '$f');
      }
    });

    test('el encargado lo puede prender desde su panel', () {
      addTearDown(() => Ajustes.oyeNana.value = false);
      final a = const Apariencia(oyeNana: true)
          .copyWith(actualizado: DateTime(2026, 11, 18));
      expect(Apariencia.deMapa(a.aMapa())!.oyeNana, isTrue);
      aplicarApariencia(a);
      expect(Ajustes.oyeNana.value, isTrue);
    });
  });

  group('Plática del adulto (sin IA)', () {
    test('los comandos de siempre hacen lo mismo que en «Hablar»', () {
      expect(_adulto('ayuda por favor').accion, AccionPlatica.ayuda);
      expect(_adulto('me cai').accion, AccionPlatica.ayuda);
      final mal = _adulto('ya tomé mi medicina pero me siento mal');
      expect((mal.accion, mal.frase), (AccionPlatica.frase, 'Me siento mal'));
      expect(_adulto('llama a mi hija').accion, AccionPlatica.familia);
      expect(
        _adulto('¿qué sigue?').texto,
        'Lo que sigue: Caminar, a las 6:00 pm.',
      );
      expect(_adulto('ya comí').frase, 'Ya comí');
    });

    test('platica un poco: hora, fecha, saludo, quién es', () {
      expect(_adulto('¿qué hora es?').texto, 'Son las 3:00 pm.');
      expect(
        respuestaAdulto(
          'que hora es',
          nombre: 'Rosa',
          queSigue: () => '',
          ahora: DateTime(2026, 11, 18, 13, 30),
        ).texto,
        'Es la 1:30 pm.',
      );
      expect(
        _adulto('¿qué día es hoy?').texto,
        'Hoy es miércoles 18 de noviembre de 2026.',
      );
      expect(_adulto('hola').texto, 'Buenas tardes, Rosa.');
      expect(_adulto('¿quién eres?').texto, startsWith('Soy NANA'));
      expect(
        _adulto('no me siento bien hoy').texto,
        startsWith('Aquí estoy contigo'),
      );
      expect(_adulto('estoy bien').texto, 'Qué gusto me da.');
    });

    test('las preguntas de medicina no se contestan', () {
      for (final f in [
        '¿qué pastilla me tomo?',
        '¿puedo tomar dos?',
        '¿cuántas pastillas me tocan?',
      ]) {
        final r = _adulto(f);
        expect(r.texto, startsWith('Eso pregúntaselo a tu médico'), reason: f);
        expect(r.accion, AccionPlatica.ninguna);
      }
    });

    test('las despedidas de todos los días también cierran la plática', () {
      for (final f in [
        'Nos vemos, NANA',
        'chao',
        'bye',
        'luego platicamos',
        'al rato platicamos',
        'hasta mañana',
        'ya me voy a dormir',
        'ya me tengo que ir',
        'ya no quiero platicar',
        'cierra',
        'ya me voy',
        'bueno, ya me voy, NANA',
        'me voy, gracias',
      ]) {
        expect(_adulto(f).accion, AccionPlatica.terminar, reason: f);
      }
      // Estas NO cierran: son saludo o siguen la plática.
      for (final f in [
        'buenas noches',
        'ya me voy a tomar la pastilla',
        'me voy a bañar y regreso',
      ]) {
        expect(_adulto(f).accion, isNot(AccionPlatica.terminar), reason: f);
      }
    });

    test(
      '«gracias NANA» o «adiós» terminan; lo desconocido explica qué decir',
      () {
        expect(_adulto('gracias Nana').accion, AccionPlatica.terminar);
        expect(_adulto('adiós').accion, AccionPlatica.terminar);
        expect(_adulto('gracias').accion, AccionPlatica.ninguna);
        expect(
          _adulto('quién ganó el partido').texto,
          contains(ayudaParaDecir),
        );
      },
    );

    test('ninguna respuesta trae consejo médico', () {
      for (final f in [
        'hola',
        'qué hora es',
        'me duele la cabeza',
        'qué medicina',
        'triste',
        'xyz',
        'ya me la tomé',
      ]) {
        expect(
          _consejo.hasMatch(_adulto(f).texto.toLowerCase()),
          isFalse,
          reason: f,
        );
      }
    });
  });

  group('Pregúntale a NANA (encargado, sin IA)', () {
    test('cómo va hoy: cuenta, medicinas y ánimo', () {
      final r = respuestaEncargado('¿Cómo va mi mamá hoy?', _datos()).texto;
      expect(r, contains('Hoy ya tomó Losartán.'));
      expect(r, contains('Le toca más tarde: Metformina a las 8:00 pm.'));
      expect(r, contains('dijo que se siente bien'));
    });

    test('la pastilla sin confirmar se dice así', () {
      final r = respuestaEncargado(
        '¿ya se tomó la pastilla?',
        _datos(hoy: const []),
      ).texto;
      expect(
        r,
        'Falta confirmar Losartán. Le toca más tarde: Metformina a las 8:00 pm.',
      );
    });

    test('la semana: tomas, faltas y días que se sintió mal', () {
      final r = respuestaEncargado('¿cómo le fue esta semana?', _datos()).texto;
      expect(r, startsWith('En los últimos 7 días Rosa tomó'));
      expect(r, contains('Dijo sentirse mal el lunes.'));
    });

    test('alertas sin atender', () {
      expect(
        respuestaEncargado('¿hay alertas?', _datos()).texto,
        'No hay alertas sin atender.',
      );
      final una = [Alerta(id: 'a', fecha: _ahora)];
      expect(
        respuestaEncargado('¿hay alertas?', _datos(alertas: una)).texto,
        contains('1 alerta'),
      );
    });

    test('no aconseja: dosis y medicinas las decide el médico', () {
      for (final f in [
        '¿le subo la dosis?',
        '¿qué medicina le doy?',
        '¿es grave?',
      ]) {
        expect(
          respuestaEncargado(f, _datos()).texto,
          startsWith('Eso lo decide su médico'),
          reason: f,
        );
      }
    });
  });

  group('Pantalla «Platicando con NANA»', () {
    tearDown(() => Servicios.voz = VozNula());

    Future<void> abrir(WidgetTester t, Widget pantalla) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => pantalla),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await t.tap(find.text('abrir'));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('saluda, contesta lo que oye y se cierra con «gracias NANA»', (
      t,
    ) async {
      final voz = VozNula(respuestas: ['qué hora es', 'gracias nana']);
      Servicios.voz = voz;
      await abrir(
        t,
        PlaticaNana(
          saludo: 'Dime, Rosa. Te escucho.',
          responder: (o) async => _adulto(o),
        ),
      );
      expect(voz.dicho, [
        'Dime, Rosa. Te escucho.',
        'Son las 3:00 pm.',
        'Aquí estoy cuando me necesites, Rosa.',
      ]);
      expect(find.byType(PlaticaNana), findsNothing);
    });

    testWidgets('dos silencios seguidos y se despide sola', (t) async {
      final voz = VozNula();
      Servicios.voz = voz;
      await abrir(
        t,
        PlaticaNana(saludo: 'Hola', responder: (o) async => _adulto(o)),
      );
      expect(voz.dicho, [
        'Hola',
        'No te escuché. ¿Me lo repites?',
        'Aquí estoy cuando me necesites.',
      ]);
      expect(find.byType(PlaticaNana), findsNothing);
    });

    testWidgets('pedir ayuda cierra la plática y avisa a quien la abrió', (
      t,
    ) async {
      Servicios.voz = VozNula(respuestas: ['me caí']);
      final acciones = <AccionPlatica>[];
      await abrir(
        t,
        PlaticaNana(
          saludo: 'Hola',
          responder: (o) async => _adulto(o),
          alAccion: (r) => acciones.add(r.accion),
        ),
      );
      expect(acciones, [AccionPlatica.ayuda]);
      expect(find.byType(PlaticaNana), findsNothing);
    });

    testWidgets('lo dicho se ve escrito (subtítulos)', (t) async {
      // La segunda frase deja a NANA "pensando": así la plática sigue
      // abierta mientras se revisa lo que ya se dijo.
      Servicios.voz = VozNula(respuestas: ['hola', 'qué hora es']);
      await t.pumpWidget(
        MaterialApp(
          home: PlaticaNana(
            saludo: 'Dime, Rosa.',
            responder: (o) async => _adulto(o),
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text('Dime, Rosa.'), findsOneWidget);
      expect(find.text('hola'), findsOneWidget);
      expect(find.text('Buenas tardes, Rosa.'), findsOneWidget);
      // Se deja terminar para no dejar timers pendientes.
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    });
  });

  group('Espera de «Oye NANA» en el inicio', () {
    late DespertadorNulo despertador;
    setUp(() {
      despertador = DespertadorNulo();
      Servicios.despertador = despertador;
    });
    tearDown(() {
      Ajustes.oyeNana.value = false;
      Servicios.despertador = DespertadorNulo();
    });

    Future<void> montar(WidgetTester t, VoidCallback alOir) => t.pumpWidget(
      MaterialApp(
        navigatorObservers: [rutasNana],
        home: Builder(
          builder: (context) => EsperaOyeNana(
            alOir: alOir,
            child: Scaffold(
              appBar: AppBar(title: const AvisoOyeNana()),
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('otra')),
                  ),
                ),
                child: const Text('ir'),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('apagado por defecto: no usa el micrófono', (t) async {
      await montar(t, () {});
      expect(despertador.empezado, 0);
      expect(find.text('Di «Oye NANA»'), findsNothing);
    });

    testWidgets('prendido: espera, se ve el aviso y al oír la frase avisa', (
      t,
    ) async {
      Ajustes.oyeNana.value = true;
      var oido = 0;
      await montar(t, () => oido++);
      await t.pump();
      expect(despertador.empezado, 1);
      expect(find.text('Di «Oye NANA»'), findsOneWidget);
      despertador.oir();
      expect(oido, 1);
    });

    testWidgets(
      'al abrir otra pantalla suelta el micrófono y al volver lo retoma',
      (t) async {
        Ajustes.oyeNana.value = true;
        await montar(t, () {});
        await t.pump();
        await t.tap(find.text('ir'));
        await t.pumpAndSettle();
        expect(despertador.parado, 1);
        expect(despertador.activo.value, isFalse);
        Navigator.of(t.element(find.text('otra'))).pop();
        await t.pumpAndSettle();
        expect(despertador.empezado, 2);
      },
    );

    testWidgets('al minimizar la app lo suelta; al volver lo retoma', (
      t,
    ) async {
      Ajustes.oyeNana.value = true;
      await montar(t, () {});
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(despertador.parado, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(despertador.empezado, 2);
    });

    testWidgets('apagar el ajuste suelta el micrófono', (t) async {
      Ajustes.oyeNana.value = true;
      await montar(t, () {});
      await t.pump();
      Ajustes.oyeNana.value = false;
      expect(despertador.parado, 1);
    });
  });
}
