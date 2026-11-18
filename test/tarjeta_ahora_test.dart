import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/dia.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/widgets/caritas_animo.dart';
import 'package:nana_app/widgets/tarjeta_ahora.dart';

const _losartan = Actividad(
  hora: '8:00',
  titulo: 'Losartán 50 mg',
  detalle: 'Tu medicina',
  tipo: TipoActividad.medicina,
  estado: EstadoActividad.ahora,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<List<String>> pintar(
    WidgetTester t,
    QueToca que, {
    Actividad? actividad,
  }) async {
    final llamadas = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarjetaAhora(
            que: que,
            actividad: actividad,
            animo: null,
            onHecha: () => llamadas.add('hecha'),
            onAbrir: () => llamadas.add('abrir'),
            onAnimo: (i) => llamadas.add('animo $i'),
          ),
        ),
      ),
    );
    return llamadas;
  }

  testWidgets(
    'Lo que toca: "Ya" anota y tocar la tarjeta abre el recordatorio',
    (t) async {
      final llamadas = await pintar(t, QueToca.actividad, actividad: _losartan);
      expect(find.text('Ahora'), findsOneWidget);
      expect(find.text('Losartán 50 mg'), findsOneWidget);
      expect(find.bySemanticsLabel('Ya me la tomé'), findsOneWidget);

      await t.tap(find.text('Ya me la tomé'));
      await t.tap(find.text('Losartán 50 mg'));
      expect(llamadas, ['hecha', 'abrir']);
    },
  );

  testWidgets('Lo que sigue también deja marcarlo, pero no abre la alarma', (
    t,
  ) async {
    final llamadas = await pintar(t, QueToca.siguiente, actividad: _losartan);
    expect(find.text('Después'), findsOneWidget);
    await t.tap(find.text('Losartán 50 mg'));
    await t.tap(find.text('Ya me la tomé'));
    expect(llamadas, ['hecha']);
  });

  testWidgets('El ánimo muestra las caritas', (t) async {
    final llamadas = await pintar(t, QueToca.animo);
    expect(find.text('¿Cómo te sientes?'), findsOneWidget);
    await t.tap(find.text(CaritasAnimo.etiquetas[1]));
    expect(llamadas, ['animo 1']);
  });

  testWidgets('Sin pendientes: todo listo', (t) async {
    await pintar(t, QueToca.listo);
    expect(find.bySemanticsLabel('Todo listo por ahora'), findsOneWidget);
  });
}
