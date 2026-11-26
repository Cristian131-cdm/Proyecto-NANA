import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/agente.dart';
import 'package:nana_app/core/conversacion_encargado.dart';
import 'package:nana_app/core/platica.dart';
import 'package:nana_app/core/resumen_encargado.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/models/registro.dart';

// Lunes 23 de noviembre de 2026, 20:15.
final _ahora = DateTime(2026, 11, 23, 20, 15);
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
  hora: TimeOfDay(hour: 21, minute: 0), // hoy todavía no le toca
  ventanaMin: 30,
);

Registro _med(Medicamento m, DateTime f) => Registro(
  tipo: TipoActividad.medicina,
  titulo: '${m.nombre} ${m.dosis}',
  idMedicamento: m.id,
  fecha: f,
  registradoPor: 'rosa',
);

DatosEncargado _datos() {
  DateTime dia(int atras, int h, [int m = 0]) =>
      DateTime(2026, 11, 23 - atras, h, m);
  return DatosEncargado(
    nombre: 'Rosa',
    meds: const [_losartan, _metformina],
    rutinas: const [],
    hoy: [_med(_losartan, dia(0, 8, 5))],
    semana: [
      for (var i = 1; i <= 6; i++) ...[
        if (i != 3) _med(_losartan, dia(i, 8, 5)), // el viernes 20 no
        _med(_metformina, dia(i, 21, 10)),
      ],
      _med(_losartan, dia(0, 8, 5)),
      Registro(
        tipo: TipoActividad.mensaje,
        titulo: 'Me siento mal',
        fecha: dia(2, 18, 40),
        registradoPor: 'rosa',
      ),
      Registro(
        tipo: TipoActividad.comida,
        titulo: 'Desayuno',
        fecha: dia(0, 9),
        registradoPor: 'rosa',
      ),
    ],
    alertas: const [],
    ahora: _ahora,
  );
}

void main() {
  group('El resumen que va al agente', () {
    test('ya va contado y por medicina', () {
      final r = resumenParaAgente(_datos());
      final t = r['totales_7_dias']! as Map;
      expect((r['dias']! as List), hasLength(7));
      expect(t['medicinas_sin_marcar'], 1);
      expect(t['dias_sin_marcar_por_medicina'], {
        'Losartán': ['viernes 20'],
        'Metformina': <String>[],
      });
      expect(t['dias_que_dijo_sentirse_mal'], ['sábado 21']);
    });

    test('hoy no cuenta como «sin marcar» lo que todavía no le toca', () {
      final hoy = (resumenParaAgente(_datos())['dias']! as List).last as Map;
      expect(hoy['dia'], 'lunes 23 (hoy)');
      expect(hoy['medicinas_sin_marcar'], isEmpty); // Metformina es a las 9 pm
      expect(hoy['medicinas_marcadas'], ['Losartán a las 8:05 am']);
    });

    test('no lleva dosis, expediente ni teléfonos', () {
      final texto = jsonEncode(resumenParaAgente(_datos()));
      expect(texto, isNot(contains('mg')));
      for (final x in [
        'telefono',
        'salud',
        'alergias',
        'padecimientos',
        'apellido',
      ]) {
        expect(texto.toLowerCase(), isNot(contains(x)), reason: x);
      }
    });
  });

  group('«Pregúntale a NANA» con agente', () {
    setUp(() {
      Servicios.repo = RepositorioMemoria();
      Servicios.reloj = () => _ahora;
    });
    tearDown(() {
      Servicios.agente = const AgenteNulo();
      Servicios.reloj = DateTime.now;
    });

    ConversacionEncargado platica() =>
        ConversacionEncargado(folio: 'rosa', nombre: 'Rosa');

    test('lo abierto se lo pregunta al agente con el resumen', () async {
      final agente = AgenteFalso(
        (_) => const RespuestaAgente(
          etiqueta: 'encargado',
          texto: 'El jueves no se marcó el Losartán.',
        ),
      );
      Servicios.agente = agente;
      final r = await platica().responder('¿Qué días no se marcó el Losartán?');
      expect(r.texto, 'El jueves no se marcó el Losartán.');
      final datos = agente.preguntasEncargado.single.datos;
      expect(datos['dias'], hasLength(7));
      expect(datos.containsKey('totales_7_dias'), isTrue);
    });

    test('lo crítico no va al agente: médico, despedida y llamar', () async {
      final agente = AgenteFalso((_) => null);
      Servicios.agente = agente;
      final p = platica();
      final medica = await p.responder('¿Le subo la dosis?');
      expect(medica.texto, startsWith('Eso lo decide su médico'));
      final llamada = await p.responder('Márcale a Rosa');
      expect(llamada.accion, AccionPlatica.llamar);
      expect(llamada.texto, 'Le marco a Rosa.');
      expect(
        (await p.responder('gracias nana')).accion,
        AccionPlatica.terminar,
      );
      expect(agente.preguntasEncargado, isEmpty);
    });

    test('las de datos van al agente y la fija queda de respaldo', () async {
      final agente = AgenteFalso((_) => null);
      Servicios.agente = agente;
      // «esta semana» antes lo contestaba la app con su resumen general,
      // aunque la pregunta fuera otra («¿dijo algo preocupante…?»).
      final r = await platica().responder(
        '¿Dijo algo preocupante esta semana?',
      );
      expect(agente.preguntasEncargado, hasLength(1));
      expect(r.texto, startsWith('En los últimos 7 días'));
    });

    test('«márcale» sí, «¿cómo se llama…?» no', () {
      final d = DatosEncargado(
        nombre: 'Rosa',
        meds: const [],
        rutinas: const [],
        hoy: const [],
        semana: const [],
        alertas: const [],
        ahora: _ahora,
      );
      for (final f in [
        'Márcale a Rosa',
        'llámale a mi mamá',
        'quiero hablar con ella',
      ]) {
        expect(
          respuestaEncargado(f, d).accion,
          AccionPlatica.llamar,
          reason: f,
        );
      }
      expect(
        respuestaEncargado('¿Cómo se llama su medicina?', d).accion,
        isNot(AccionPlatica.llamar),
      );
    });

    test('si el agente no contesta, la frase de siempre', () async {
      Servicios.agente = AgenteFalso((_) => null);
      final r = await platica().responder('¿Cómo durmió anoche?');
      expect(r.texto, startsWith('Todavía no sé contestar eso'));
    });

    test('sin servidor no se le pregunta', () async {
      final r = await platica().responder('¿Cómo durmió anoche?');
      expect(r.texto, startsWith('Todavía no sé contestar eso'));
    });
  });
}
