import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/dia.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/core/tema.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/screens/mi_dia.dart';
import 'package:nana_app/screens/mi_familia.dart';
import 'package:nana_app/screens/nana_escucha.dart';
import 'package:nana_app/screens/panel_adulto.dart';
import 'package:nana_app/screens/recordatorio_alarma.dart';
import 'package:nana_app/screens/senas.dart';
import 'package:nana_app/screens/tablero_frases.dart';

// Lo que necesita TalkBack / VoiceOver en cada pantalla del adulto:
// todo lo que se toca tiene nombre y mide al menos 48 x 48.
const _losartan = Actividad(
  hora: '8:00',
  titulo: 'Losartán 50 mg',
  detalle: 'Tu medicina',
  tipo: TipoActividad.medicina,
  estado: EstadoActividad.ahora,
  idMedicamento: 'losartan',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Servicios.repo = RepositorioMemoria(sesion: 'rosa-cel'));

  final pantallas = <String, Widget Function()>{
    'Inicio del adulto': () => const PanelAdulto(),
    'Mi día': () => MiDia(folio: 'rosa', onHecha: (_) {}, onAbrir: (_) {}),
    'Mi familia': () => const MiFamilia(folio: 'rosa'),
    'Hablar con NANA': () => NanaEscucha(nombre: 'Rosa', onFrase: (_) {}),
    'Decir (tablero)': () => TableroFrases(onFrase: (_) {}, onHablar: () {}),
    'Recordatorio': () =>
        const RecordatorioAlarma(actividad: _losartan, nombre: 'Rosa'),
    'Ver en señas': () => const VerEnSenas(),
    'Permiso de cámara': () => const ConsentimientoCamara(),
    'Cámara de señas': () => const CamaraSenas(),
  };

  for (final MapEntry(key: nombre, value: crear) in pantallas.entries) {
    testWidgets('$nombre: todo lo que se toca tiene nombre y buen tamaño', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(420, 2400);
      addTearDown(t.view.reset);
      final manija = t.ensureSemantics();
      await t.pumpWidget(MaterialApp(theme: TemaNana.tema, home: crear()));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 250));
      }
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      manija.dispose();
    });
  }

  test('NANA cuenta todo el día con hora y estado', () {
    expect(
      textoMiDia(const [_losartan]),
      'Tu día. Llevas 0 de 1. 8:00, Losartán 50 mg: toca ahora.',
    );
    expect(textoMiDia(const []), 'Hoy no tienes nada anotado.');
  });

  testWidgets('Con "Que me hable", Mi día se lee solo al abrirlo', (t) async {
    final voz = VozNula();
    Servicios.voz = voz;
    Ajustes.queMeHable.value = true;
    addTearDown(() {
      Ajustes.queMeHable.value = false;
      Servicios.voz = VozNula();
    });
    await t.pumpWidget(
      MaterialApp(
        home: MiDia(folio: 'rosa', onHecha: (_) {}, onAbrir: (_) {}),
      ),
    );
    await t.pumpAndSettle();
    expect(voz.dicho, hasLength(1));
    expect(voz.dicho.single, startsWith('Tu día. Llevas 0 de 4.'));
  });

  testWidgets('Sin "Que me hable" NANA no habla sola, pero Léeme sí lee', (
    t,
  ) async {
    final voz = VozNula();
    Servicios.voz = voz;
    addTearDown(() => Servicios.voz = VozNula());
    await t.pumpWidget(const MaterialApp(home: MiFamilia(folio: 'rosa')));
    await t.pumpAndSettle();
    expect(voz.dicho, isEmpty);
    await t.tap(find.byTooltip('Léeme esta pantalla'));
    await t.pump();
    expect(voz.dicho, hasLength(1));
  });
}
