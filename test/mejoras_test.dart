import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/biometria.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/demo.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/panel_cuidador.dart';
import 'package:nana_app/screens/pestana_medicamentos.dart';
import 'package:nana_app/screens/pestana_semana.dart';
import 'package:nana_app/widgets/ajustes_texto.dart';

class _SinHuella implements Biometria {
  @override
  Future<bool> disponible() async => false;
  @override
  Future<bool> autenticar(String motivo) async => false;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Servicios.repo = RepositorioMemoria();
    Servicios.biometria = _SinHuella();
  });

  testWidgets('El cuidador ve solo las opciones que sirven a cualquiera', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarAjustesTexto(context, paraCuidador: true),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Abrir'));
    await t.pumpAndSettle();

    expect(find.text('Colores más fuertes'), findsOneWidget);
    expect(find.text('Menos movimiento'), findsOneWidget);
    expect(find.text('Que me hable'), findsNothing);
    expect(find.text('Contestar tocando'), findsNothing);
  });

  testWidgets('El anillo dice cuánto lleva el adulto hoy', (t) async {
    final s = t.ensureSemantics();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnilloDelDia(folio: 'rosa', nombre: 'Rosa'),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Losartán + desayuno, comida y caminar de ejemplo.
    expect(
      find.bySemanticsLabel(RegExp('Rosa: lleva 0 de 4 hoy')),
      findsOneWidget,
    );
    s.dispose();
  });

  testWidgets('Borrar una medicina se puede deshacer', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PestanaMedicamentos(folio: 'rosa')),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Borrar Losartán'));
    await t.pumpAndSettle();
    expect(find.text('Borré Losartán'), findsOneWidget);

    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();
    final meds = await Servicios.repo.medicamentos('rosa').first;
    expect(meds.single.nombre, 'Losartán');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('Tocar un día de la Semana muestra lo que pasó', (t) async {
    final repo = Servicios.repo as RepositorioMemoria;
    final ahora = DateTime.now();
    await cargarDemo(repo, 'rosa', ahora);
    final s = t.ensureSemantics();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PestanaSemana(adulto: 'Rosa', folio: 'rosa'),
        ),
      ),
    );
    await t.pumpAndSettle();

    // El primer día (hace 6 días) tiene datos de la demostración.
    await t.tap(find.bySemanticsLabel(RegExp('Toca para ver el día')).first);
    await t.pumpAndSettle();
    expect(find.text('Lo que se anotó'), findsOneWidget);
    expect(find.textContaining('Desayuno'), findsWidgets);
    s.dispose();
  });
}
