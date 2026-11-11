import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/alarmas.dart';
import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/dia.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/screens/nana_escucha.dart';
import 'package:nana_app/screens/recordatorio_alarma.dart';

class _AlarmasFalsas implements Alarmas {
  final pospuestas = <String>[];
  @override
  String? get abiertaDesde => null;
  @override
  Future<void> iniciar(void Function(String) alTocar) async {}
  @override
  Future<void> programar(String nombreAdulto, List<Medicamento> meds) async {}
  @override
  Future<void> posponer(
    String idMedicamento,
    String texto,
    Duration en,
  ) async => pospuestas.add(idMedicamento);
}

const _losartan = Actividad(
  hora: '8:00',
  titulo: 'Losartán 50 mg',
  detalle: 'Tu medicina',
  tipo: TipoActividad.medicina,
  estado: EstadoActividad.ahora,
  idMedicamento: 'losartan',
);

// Abre el recordatorio desde un botón y guarda lo que regresó.
Future<List<bool?>> _abrirRecordatorio(WidgetTester t) async {
  final resultado = <bool?>[];
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => resultado.add(
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => const RecordatorioAlarma(
                  actividad: _losartan,
                  nombre: 'Rosa',
                ),
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await t.tap(find.text('abrir'));
  await t.pump();
  await t.pump();
  return resultado;
}

// La mascota late sin parar, así que no sirve pumpAndSettle.
Future<void> _esperar(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _AlarmasFalsas alarmas;
  setUp(() {
    Ajustes.sinVoz.value = false;
    Ajustes.queMeHable.value = false;
    alarmas = _AlarmasFalsas();
    Servicios.alarmas = alarmas;
    addTearDown(() {
      Servicios.voz = VozNula();
      Servicios.alarmas = AlarmasLocales();
    });
  });

  group('Entender sin IA', () {
    test('Se quitan acentos, mayúsculas y signos', () {
      expect(normalizar('¿Ya me la TOMÉ?'), 'ya me la tome');
    });

    test('Sí y al rato en el recordatorio', () {
      RespuestaRecordatorio? r(String? s) =>
          entender(s, respuestasRecordatorio);
      expect(r('Sí, ya me la tomé'), RespuestaRecordatorio.si);
      expect(r('listo'), RespuestaRecordatorio.si);
      expect(r('Al rato'), RespuestaRecordatorio.alRato);
      expect(r('todavía no'), RespuestaRecordatorio.alRato);
      // "ya no" no es un sí
      expect(r('ya no'), RespuestaRecordatorio.alRato);
      expect(r('el perro ladra'), isNull);
      expect(r(null), isNull);
    });

    test('Una palabra dentro de otra no cuenta', () {
      // "sigue" contiene "si", pero no es un sí
      expect(entender('sigue', respuestasRecordatorio), isNull);
    });

    test('Comandos al hablar con NANA: lo preocupante gana', () {
      String? c(String s) => entender(s, NanaEscucha.comandos);
      expect(c('ya tomé mi medicina pero me siento mal'), 'Me siento mal');
      expect(c('ayúdame, necesito ayuda'), 'Necesito ayuda');
      expect(c('¿qué me toca?'), '¿Qué sigue hoy?');
      expect(c('llama a mi hija'), 'familia');
      expect(c('ya comí'), 'Ya comí');
    });
  });

  test('NANA cuenta el día en una frase', () {
    final texto = textoDelDia(
      saludo: 'Buenos días, Rosa',
      dia: [_losartan],
      animoHoy: null,
      ahora: DateTime(2026, 11, 11, 8),
    );
    expect(
      texto,
      'Buenos días, Rosa. Hoy llevas 0 de 1. Ahora te toca tu Losartán 50 mg.',
    );
  });

  testWidgets(
    'El recordatorio pregunta en voz alta y "ya me la tomé" confirma',
    (t) async {
      final voz = VozNula(respuestas: ['sí, ya me la tomé']);
      Servicios.voz = voz;
      final resultado = await _abrirRecordatorio(t);
      await _esperar(t);
      expect(
        voz.dicho.first,
        'Rosa, son las 8:00. Te toca tu Losartán 50 mg. ¿Ya te la tomaste?',
      );
      expect(voz.dicho, contains('Listo, anoté tu Losartán 50 mg'));
      expect(resultado, [true]);
    },
  );

  testWidgets('"Al rato" por voz pospone la alarma 10 minutos', (t) async {
    Servicios.voz = VozNula(respuestas: ['al rato']);
    final resultado = await _abrirRecordatorio(t);
    await _esperar(t);
    expect(alarmas.pospuestas, ['losartan']);
    expect(resultado, [false]);
  });

  testWidgets('Si no entiende, pregunta otra vez y luego espera el botón', (
    t,
  ) async {
    final voz = VozNula(respuestas: ['mmm', 'qué']);
    Servicios.voz = voz;
    final resultado = await _abrirRecordatorio(t);
    await _esperar(t);
    expect(voz.dicho, contains('No te entendí. Dime sí, o al rato.'));
    expect(resultado, isEmpty);
    await t.tap(find.text('Ya me la tomé'));
    await _esperar(t);
    expect(resultado, [true]);
  });

  testWidgets('Quien no habla: NANA pregunta pero no prende el micrófono', (
    t,
  ) async {
    Ajustes.sinVoz.value = true;
    final voz = VozNula(respuestas: ['sí']);
    Servicios.voz = voz;
    final resultado = await _abrirRecordatorio(t);
    await _esperar(t);
    expect(voz.dicho, hasLength(1));
    expect(voz.respuestas, ['sí']); // nadie lo escuchó
    expect(resultado, isEmpty);
  });

  testWidgets('Hablando con NANA: "me siento mal" se le cuenta a la familia', (
    t,
  ) async {
    final dichas = <String>[];
    Servicios.voz = VozNula(respuestas: ['me siento mal']);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NanaEscucha(nombre: 'Rosa', onFrase: dichas.add),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(dichas, ['Me siento mal']);
  });
}
