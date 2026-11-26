import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nana_app/core/agente.dart';
import 'package:nana_app/core/ocr_receta.dart';
import 'package:nana_app/core/preprocesar_foto.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/medicina_leida.dart';
import 'package:nana_app/screens/leer_receta.dart';

const losartan = MedicinaLeida(
  nombre: 'Losartán',
  dosis: '50',
  unidad: 'mg',
  horas: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
  dudas: ['La receta dice cada 12 h; puse la primera a las 8:00.'],
);

void main() {
  group('lo que manda el agente', () {
    test('se convierte en una medicina por hora', () {
      final m = MedicinaLeida.deJson({
        'nombre': 'Losartán',
        'dosis': '50',
        'unidad': 'mg',
        'horas': ['08:00', '20:00', 'mañana'],
        'dias': 30,
        'dudas': [],
      })!;
      final meds = m.comoMedicamentos();
      expect(meds.map((x) => (x.nombre, x.dosis, x.horaTexto)), [
        ('Losartán', '50 mg', '08:00'),
        ('Losartán', '50 mg', '20:00'),
      ]);
      expect(m.dias, 30);
    });

    test('descarta lo que no cuadra', () {
      expect(MedicinaLeida.deJson({'nombre': '', 'dosis': '5'}), isNull);
      expect(
        MedicinaLeida.deJson({'nombre': 'X', 'dosis': '5', 'horas': []}),
        isNull,
      );
      expect(medicinasDeJson({'medicinas': 'no'}), isNull);
      expect(
        medicinasDeJson({
          'medicinas': [
            {'nombre': 'A'},
            {
              'nombre': 'Metformina',
              'dosis': '850',
              'unidad': 'mg',
              'horas': ['8:00'],
            },
          ],
        })!.map((m) => m.nombre),
        ['Metformina'],
      );
    });
  });

  group('preprocesado de la foto', () {
    test('corrige la luz despareja y deja la letra oscura', () {
      // Papel de 2000×1000: a la izquierda en sombra (60), a la derecha con
      // luz (200), con renglones delgados de "letra" un 40 % más oscuros.
      final foto = img.Image(width: 2000, height: 1000);
      for (final p in foto) {
        final papel = 60 + 140 * p.x / 1999;
        final letra = p.y % 100 < 5; // renglón de 5 px cada 100 px
        final v = (letra ? papel * 0.6 : papel).round();
        p
          ..r = v
          ..g = v
          ..b = v;
      }
      final salida = img.decodePng(prepararFoto(img.encodeJpg(foto))!)!;
      expect(salida.width, anchoMaximo);
      // A 1600 px los renglones quedan en y = 0..3, 80..83, …
      final fondoSombra = salida.getPixel(100, 40).r;
      final fondoLuz = salida.getPixel(1500, 40).r;
      final letraSombra = salida.getPixel(100, 81).r;
      expect(fondoSombra, greaterThan(200)); // la sombra se quitó
      expect(fondoLuz, greaterThan(200));
      expect(letraSombra, lessThan(120)); // la letra sigue oscura
    });

    test('bytes que no son imagen → null', () {
      expect(prepararFoto(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('pantalla «¿Está bien así?»', () {
    late RepositorioMemoria repo;
    late AgenteFalso agente;

    setUp(() {
      repo = RepositorioMemoria();
      agente = AgenteFalso((_) => null)..receta = [losartan];
      Servicios.repo = repo;
      Servicios.agente = agente;
      Servicios.voz = VozNula();
      Servicios.ocr = const OcrFalso('Losartán 50 mg cada 12 horas');
    });

    Future<int?> abrir(WidgetTester t) async {
      int? resultado;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultado = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeerReceta(folio: 'F1'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await t.tap(find.text('abrir'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      return resultado;
    }

    testWidgets('lee, muestra para revisar y guarda solo al confirmar', (
      t,
    ) async {
      await abrir(t);
      expect(find.text('¿Está bien así?'), findsOneWidget);
      expect(agente.recetasLeidas, ['Losartán 50 mg cada 12 horas']);
      expect(find.text('8:00 am'), findsOneWidget);
      expect(find.textContaining('cada 12 h'), findsOneWidget);
      expect(await repo.medicamentos('F1').first, isEmpty);

      await t.tap(find.text('Sí, guardar'));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      final guardadas = await repo.medicamentos('F1').first;
      expect(guardadas.map((m) => (m.dosis, m.horaTexto)), [
        ('50 mg', '08:00'),
        ('50 mg', '20:00'),
      ]);
    });

    testWidgets('una dosis mal escrita no se guarda', (t) async {
      await abrir(t);
      await t.enterText(find.widgetWithText(TextField, '50'), '.5');
      await t.tap(find.text('Sí, guardar'));
      await t.pump();
      expect(await repo.medicamentos('F1').first, isEmpty);
    });

    testWidgets('sin agente lo dice y ofrece agregar a mano', (t) async {
      agente.receta = null;
      await abrir(t);
      expect(find.text('NANA no pudo leer la receta'), findsOneWidget);
      expect(find.text('Agregar a mano'), findsOneWidget);
    });
  });
}
