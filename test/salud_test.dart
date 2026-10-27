import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/lector_expediente.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/salud.dart';
import 'package:nana_app/screens/formulario_salud.dart';
import 'package:nana_app/screens/pestana_historial.dart';

class _LectorFalso implements LectorExpediente {
  final bool falla;
  _LectorFalso({this.falla = false});

  @override
  bool get esSimulado => true;

  @override
  Future<Archivo?> elegir() async =>
      (nombre: 'expediente.pdf', bytes: Uint8List(0));

  @override
  Future<Salud> leer(Archivo archivo) async {
    if (falla) throw Exception('no se pudo');
    return const Salud(
      padecimientos: ['Hipertensión'],
      alergias: ['Penicilina'],
      medicamentos: ['Losartán 50 mg'],
      origen: 'documento',
    );
  }
}

Future<void> _tocar(WidgetTester t, String texto) async {
  await t.scrollUntilVisible(
    find.text(texto),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(find.text(texto));
  await t.pumpAndSettle();
}

// Un MaterialApp con un botón que abre el formulario, para ver que regresa.
Widget _conFormulario() => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const FormularioSalud(folio: 'rosa', nombre: 'Rosa'),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  ),
);

void main() {
  late RepositorioMemoria repo;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    repo = RepositorioMemoria();
    Servicios.repo = repo;
    Servicios.lector = _LectorFalso();
  });
  tearDown(() => Servicios.lector = const LectorSimulado());

  test('La salud se guarda y se lee como se escribió', () async {
    const s = Salud(
      padecimientos: ['Hipertensión'],
      alergias: ['Penicilina'],
      discapacidades: ['No oye bien'],
      pesoKg: 62.5,
      estaturaCm: 158,
      notas: 'Usa bastón',
    );
    final copia = Salud.deMapa(s.aMapa());
    expect(copia.padecimientos, ['Hipertensión']);
    expect(copia.pesoKg, 62.5);
    expect(copia.estaturaCm, 158);

    expect((await repo.salud('rosa').first).estaVacia, isTrue);
    await repo.guardarSalud('rosa', s);
    final guardada = await repo.salud('rosa').first;
    expect(guardada.alergias, ['Penicilina']);
    expect(guardada.actualizado, isNotNull);
  });

  testWidgets('A mano: se agrega y se quita un padecimiento y se guarda',
      (t) async {
    await t.pumpWidget(_conFormulario());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('¿Qué padece Rosa?'), findsOneWidget);

    final campo = find.widgetWithText(TextField, 'Por ejemplo: Hipertensión');
    await t.enterText(campo, 'Artritis');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.enterText(campo, 'Asma');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Quitar Asma'));
    await t.pumpAndSettle();
    expect(find.text('Asma'), findsNothing);

    await _tocar(t, 'Guardar');
    final s = await repo.salud('rosa').first;
    expect(s.padecimientos, ['Artritis']);
    expect(s.origen, 'manual');
    expect(find.text('abrir'), findsOneWidget); // regresó
  });

  testWidgets('El expediente llena el formulario y la familia lo confirma',
      (t) async {
    await t.pumpWidget(_conFormulario());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Subir expediente (PDF o foto)'));
    await t.pumpAndSettle();

    expect(find.text('Revisa lo que encontré'), findsOneWidget);
    expect(find.textContaining('Demostración'), findsOneWidget);
    expect(find.text('Penicilina'), findsOneWidget);
    // Nada se guarda hasta que la familia confirma.
    expect((await repo.salud('rosa').first).estaVacia, isTrue);

    await _tocar(t, 'Sí, es correcto, guardar');
    final s = await repo.salud('rosa').first;
    expect(s.padecimientos, ['Hipertensión']);
    expect(s.medicamentos, ['Losartán 50 mg']);
    expect(s.origen, 'documento');
  });

  testWidgets('Si no se puede leer el documento lo dice con calma',
      (t) async {
    Servicios.lector = _LectorFalso(falla: true);
    await t.pumpWidget(_conFormulario());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Subir expediente (PDF o foto)'));
    await t.pumpAndSettle();

    expect(
      find.text('No se pudo leer el documento. Puedes llenarlo a mano.'),
      findsOneWidget,
    );
  });

  testWidgets('El peso con letras no se guarda', (t) async {
    await t.pumpWidget(_conFormulario());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    final peso = find.widgetWithText(TextField, 'Peso (kg)');
    await t.scrollUntilVisible(
      peso,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(peso, 'mucho');
    await _tocar(t, 'Guardar');

    expect(find.text('Escribe el peso en kilos'), findsOneWidget);
    expect((await repo.salud('rosa').first).estaVacia, isTrue);
  });

  testWidgets('Historial muestra lo guardado y deja editarlo', (t) async {
    await repo.guardarSalud(
      'rosa',
      const Salud(padecimientos: ['Hipertensión'], alergias: ['Penicilina']),
    );
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PestanaHistorial(adulto: 'Rosa', folio: 'rosa')),
      ),
    );
    await t.pumpAndSettle();

    await t.scrollUntilVisible(find.text('Editar datos de salud'), 300);
    expect(find.text('Hipertensión'), findsOneWidget);
    expect(find.text('Alergia: Penicilina'), findsOneWidget);
    await t.pumpAndSettle();
    await t.tap(find.text('Editar datos de salud'));
    await t.pumpAndSettle();
    expect(find.text('¿Qué padece Rosa?'), findsOneWidget);
  });
}
