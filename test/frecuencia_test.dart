import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nana_app/core/dia.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/models/medicamento.dart';
import 'package:nana_app/screens/pestana_medicamentos.dart';

void main() {
  test('la hora siempre dice am o pm', () {
    expect(horaCorta(const TimeOfDay(hour: 8, minute: 0)), '8:00 am');
    expect(horaCorta(const TimeOfDay(hour: 20, minute: 30)), '8:30 pm');
    expect(horaCorta(const TimeOfDay(hour: 12, minute: 0)), '12:00 pm');
    expect(horaCorta(const TimeOfDay(hour: 0, minute: 5)), '12:05 am');
  });

  test('«cada N horas» calcula las tomas del día', () {
    String tomas(int h, int cada) => horasPorFrecuencia(
      TimeOfDay(hour: h, minute: 0),
      cada,
    ).map(horaCorta).join(' · ');
    expect(tomas(8, 24), '8:00 am');
    expect(tomas(8, 12), '8:00 am · 8:00 pm');
    expect(tomas(8, 8), '8:00 am · 4:00 pm · 12:00 am');
    expect(tomas(6, 6), '6:00 am · 12:00 pm · 6:00 pm · 12:00 am');
    expect(tomas(8, 7), '8:00 am'); // no cabe parejo en el día
  });

  test('empieza en la hora de ahora y am/pm cambia con un toque', () {
    expect(horaCorta(horaSugerida(DateTime(2026, 11, 25, 18, 42))), '6:45 pm');
    expect(horaCorta(horaSugerida(DateTime(2026, 11, 25, 23, 58))), '12:00 am');
    expect(horaCorta(horaSugerida(DateTime(2026, 11, 25, 8, 0))), '8:00 am');
    const ocho = TimeOfDay(hour: 8, minute: 30);
    expect(horaCorta(conMitad(ocho, pm: true)), '8:30 pm');
    expect(horaCorta(conMitad(conMitad(ocho, pm: true), pm: false)), '8:30 am');
    expect(
      horaCorta(conMitad(const TimeOfDay(hour: 12, minute: 0), pm: false)),
      '12:00 am',
    );
  });

  testWidgets('«Cada 8 horas» guarda una medicina por toma', (t) async {
    Servicios.reloj = () => DateTime(2026, 11, 25, 7, 58);
    addTearDown(() => Servicios.reloj = DateTime.now);
    final guardadas = <Medicamento>[];
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FormularioMedicamento(onGuardar: guardadas.add),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Medicamento'),
      'Amoxicilina',
    );
    await t.enterText(find.widgetWithText(TextField, 'Dosis'), '500');
    await t.tap(find.text('Cada 8 horas'));
    await t.pump();
    // Con un toque en «pm» la primera toma pasa a la noche, y de regreso.
    await t.tap(find.text('pm'));
    await t.pump();
    expect(find.text('Primera toma: 8:00 pm'), findsOneWidget);
    await t.tap(find.text('am'));
    await t.pump();
    expect(find.text('Primera toma: 8:00 am'), findsOneWidget);
    expect(
      find.text('Se toma a las: 8:00 am · 4:00 pm · 12:00 am'),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('Guardar'));
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    // Se guardan ordenadas por hora del día.
    expect(guardadas.map((m) => (m.nombre, m.dosis, horaCorta(m.hora))), [
      ('Amoxicilina', '500 mg', '12:00 am'),
      ('Amoxicilina', '500 mg', '8:00 am'),
      ('Amoxicilina', '500 mg', '4:00 pm'),
    ]);
  });

  testWidgets('cabe con la letra al máximo en un celular angosto', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 1400),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(body: FormularioMedicamento(onGuardar: (_) {})),
        ),
      ),
    );
    await t.tap(find.text('Cada 8 horas'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
