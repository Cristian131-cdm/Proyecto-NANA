import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/agente.dart';
import 'package:nana_app/core/agente_red.dart';
import 'package:nana_app/core/conversacion_adulto.dart';
import 'package:nana_app/core/platica.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/models/actividad.dart';

const _losartan = Actividad(
  hora: '8:00',
  titulo: 'Losartán 50 mg',
  detalle: 'Tu medicina',
  tipo: TipoActividad.medicina,
  estado: EstadoActividad.pendiente,
  idMedicamento: 'med1',
);
const _desayuno = Actividad(
  hora: '9:00',
  titulo: 'Desayuno',
  detalle: '',
  tipo: TipoActividad.comida,
  estado: EstadoActividad.hecha,
);
const _dia = [_losartan, _desayuno];

RespuestaAgente _dice(
  String texto, {
  String accion = '',
  PropuestaAgente? propuesta,
}) => RespuestaAgente(
  etiqueta: 'compania',
  texto: texto,
  accion: accion,
  propuesta: propuesta,
);

void main() {
  late List<Actividad> anotadas;
  ConversacionAdulto platica() => ConversacionAdulto(
    nombre: 'Rosa',
    queSigue: () => 'Lo que sigue: Losartán a las 8:00.',
    dia: () => _dia,
    anotar: anotadas.add,
  );

  setUp(() {
    anotadas = [];
    Servicios.reloj = () => DateTime(2026, 11, 23, 10);
  });
  tearDown(() {
    Servicios.agente = const AgenteNulo();
    Servicios.reloj = DateTime.now;
  });

  group('Datos para el agente', () {
    test('la IP se completa con http y el puerto 8787', () {
      expect(urlDelServidor('192.168.100.3'), 'http://192.168.100.3:8787');
      expect(
        urlDelServidor(' 192.168.100.3:9000/ '),
        'http://192.168.100.3:9000',
      );
      expect(urlDelServidor('http://laptop.local'), 'http://laptop.local:8787');
      expect(urlDelServidor(''), isNull);
      // El túnel de Cloudflare va por https sin puerto.
      expect(
        urlDelServidor('https://gato-azul.trycloudflare.com/'),
        'https://gato-azul.trycloudflare.com',
      );
    });

    test('el día lleva id, tipo, título, hora y si ya se hizo', () {
      expect(diaParaAgente(_dia), [
        {
          'id': 'med1',
          'tipo': 'medicina',
          'titulo': 'Losartán 50 mg',
          'hora': '8:00',
          'hecho': false,
        },
        {
          'id': 'a1',
          'tipo': 'comida',
          'titulo': 'Desayuno',
          'hora': '9:00',
          'hecho': true,
        },
      ]);
      expect(actividadPropuesta(_dia, 'a1'), _desayuno);
      expect(actividadPropuesta(_dia, 'zzz'), isNull);
    });

    test('lee la respuesta de Python', () {
      final r = RespuestaAgente.deJson({
        'etiqueta': 'registro',
        'texto': '¿Anoto que ya te tomaste Losartán?',
        'accion': '',
        'propuesta': {'tipo': 'registro', 'id': 'med1', 'pregunta': '¿Anoto…?'},
        'proveedor': 'ollama:qwen3:8b',
      })!;
      expect(r.propuesta!.id, 'med1');
      expect(r.proveedor, 'ollama:qwen3:8b');
      expect(RespuestaAgente.deJson({'texto': '  '}), isNull);
      expect(RespuestaAgente.deJson('nada'), isNull);
    });

    test('las acciones del agente abren lo mismo que las reglas', () {
      expect(
        respuestaDelAgente(_dice('x', accion: 'abrir_ayuda')).accion,
        AccionPlatica.ayuda,
      );
      expect(
        respuestaDelAgente(_dice('x', accion: 'abrir_familia')).accion,
        AccionPlatica.familia,
      );
      expect(
        respuestaDelAgente(_dice('x', accion: 'abrir_mi_dia')).accion,
        AccionPlatica.ninguna,
      );
    });
  });

  group('La plática con agente', () {
    test('la plática la contesta el agente', () async {
      final agente = AgenteFalso((_) => _dice('Aquí estoy contigo, Rosa.'));
      Servicios.agente = agente;
      final r = await platica().responder('me siento sola');
      expect(r.texto, 'Aquí estoy contigo, Rosa.');
      expect(agente.pedidos.single.dia, hasLength(2));
    });

    test('lo crítico no pasa por el agente', () async {
      final agente = AgenteFalso((_) => _dice('no debería'));
      Servicios.agente = agente;
      final p = platica();
      expect((await p.responder('me caí')).accion, AccionPlatica.ayuda);
      expect(
        (await p.responder('llama a mi familia')).accion,
        AccionPlatica.familia,
      );
      expect(
        (await p.responder('qué pastilla me tomo')).texto,
        startsWith('Eso pregúntaselo'),
      );
      expect((await p.responder('qué hora es')).texto, 'Son las 10:00.');
      expect(agente.pedidos, isEmpty);
    });

    test('si el agente no contesta, la respuesta de siempre', () async {
      Servicios.agente = AgenteFalso((_) => null);
      final r = await platica().responder('me siento triste');
      expect(r.texto, startsWith('Aquí estoy contigo. Si quieres hablar'));
    });

    test('sin servidor configurado no se le pregunta', () async {
      final r = await platica().responder('cuéntame algo bonito');
      expect(r.texto, startsWith('Todavía no entiendo eso'));
    });

    test('recuerda lo que ya se platicó', () async {
      final agente = AgenteFalso((t) => _dice('Te escucho.'));
      Servicios.agente = agente;
      final p = platica();
      await p.responder('hola nana');
      await p.responder('me siento sola');
      expect(agente.pedidos.map((x) => x.historial), [0, 2]);
    });

    test('propuesta + «sí» anota la medicina', () async {
      Servicios.agente = AgenteFalso(
        (_) => _dice(
          '¿Anoto que ya te tomaste Losartán?',
          propuesta: const PropuestaAgente(
            tipo: 'registro',
            id: 'med1',
            pregunta: '¿Anoto…?',
          ),
        ),
      );
      final p = platica();
      expect(
        (await p.responder('ya me eché la del corazón')).texto,
        '¿Anoto que ya te tomaste Losartán?',
      );
      expect((await p.responder('sí')).texto, 'Listo, ya lo anoté.');
      expect(anotadas, [_losartan]);
    });

    test('propuesta + «no» no anota', () async {
      Servicios.agente = AgenteFalso(
        (_) => _dice(
          '¿Anoto…?',
          propuesta: const PropuestaAgente(
            tipo: 'registro',
            id: 'med1',
            pregunta: '¿Anoto…?',
          ),
        ),
      );
      final p = platica();
      await p.responder('ya me eché la del corazón');
      expect((await p.responder('no')).texto, 'Está bien, no lo anoto.');
      expect(anotadas, isEmpty);
    });
  });

  group('AgenteEnRed', () {
    late HttpServer servidor;
    late Future<void> Function(HttpRequest) atender;

    setUp(() async {
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servidor.listen((p) => atender(p));
    });
    tearDown(() => servidor.close(force: true));

    AgenteEnRed agente({Duration limite = const Duration(seconds: 2)}) =>
        AgenteEnRed(
          limite: limite,
          servidor: () => '127.0.0.1:${servidor.port}',
        );

    Future<void> json(HttpRequest p, int codigo, Object cuerpo) async {
      p.response
        ..statusCode = codigo
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(cuerpo));
      await p.response.close();
    }

    test('manda la frase y lee la respuesta', () async {
      Map<String, dynamic>? recibido;
      int? largo;
      atender = (p) async {
        // El servidor de Python lee Content-Length: sin él (chunked) toma la
        // petición como vacía. Así falló en el A72 el 2026-11-23.
        largo = p.headers.contentLength;
        recibido = jsonDecode(
          await utf8.decoder.bind(p).join(),
        ) as Map<String, dynamic>;
        await json(p, 200, {
          'etiqueta': 'compania',
          'texto': 'Hola, Rosa.',
          'accion': '',
        });
      };
      final r = await agente().preguntar(
        texto: 'hola',
        nombre: 'Rosa',
        dia: diaParaAgente(_dia),
        historial: const [],
      );
      expect(r!.texto, 'Hola, Rosa.');
      expect(largo, greaterThan(0));
      expect(recibido!['nombre'], 'Rosa');
      expect(recibido!['dia'], hasLength(2));
    });

    test('un error del servidor regresa null', () async {
      atender = (p) => json(p, 500, {'error': 'falló'});
      expect(
        await agente().preguntar(
          texto: 'hola',
          nombre: 'Rosa',
          dia: const [],
          historial: const [],
        ),
        isNull,
      );
    });

    test('si tarda más del límite regresa null', () async {
      atender = (p) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await json(p, 200, {'texto': 'tarde'});
      };
      final inicio = DateTime.now();
      final r = await agente(limite: const Duration(milliseconds: 300))
          .preguntar(
            texto: 'hola',
            nombre: 'Rosa',
            dia: const [],
            historial: const [],
          );
      expect(r, isNull);
      expect(DateTime.now().difference(inicio).inMilliseconds, lessThan(1500));
    });

    test('«Probar» dice qué modelo contesta', () async {
      atender = (p) => json(p, 200, {'ok': true, 'ollama': 'qwen3:8b'});
      final s = await agente().salud();
      expect(s!.modelo, 'qwen3:8b');
      expect(s.claveOk, isTrue);
    });

    test('manda la clave de la demo y «Probar» dice si coincide', () async {
      String? recibida;
      atender = (p) {
        recibida = p.headers.value('X-Nana-Demo');
        return json(p, 200, {
          'ok': true,
          'ollama': 'qwen3:8b',
          'pide_clave': true,
          'clave_ok': recibida == '482913',
        });
      };
      AgenteEnRed con(String clave) => AgenteEnRed(
        servidor: () => '127.0.0.1:${servidor.port}',
        clave: () => clave,
      );
      expect((await con('482913').salud())!.claveOk, isTrue);
      expect(recibida, '482913');
      expect((await con('000000').salud())!.claveOk, isFalse);
      // Sin clave no manda el encabezado.
      await con('').salud();
      expect(recibida, isNull);
    });

    test('sin IP no está disponible y no pregunta', () async {
      final a = AgenteEnRed(servidor: () => '');
      expect(a.disponible, isFalse);
      expect(await a.salud(), isNull);
    });
  });
}
