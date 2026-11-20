import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/biometria.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/bienvenida.dart';
import 'package:nana_app/screens/codigo_vinculacion.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/mis_ajustes.dart';
import 'package:nana_app/screens/panel_cuidador.dart';
import 'package:nana_app/screens/pantalla_del_adulto.dart';
import 'package:nana_app/screens/resumen_expediente.dart';
import 'package:nana_app/screens/pestana_mas.dart';
import 'package:nana_app/screens/pestana_rutinas.dart';

// La huella real deja temporizadores en pruebas.
class _SinHuella implements Biometria {
  @override
  Future<bool> disponible() async => false;
  @override
  Future<bool> autenticar(String motivo) async => false;
}

Future<void> _esperar(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Servicios.repo = RepositorioMemoria();
    Servicios.biometria = _SinHuella();
  });

  Future<void> abrir(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: PanelCuidador()));
    await _esperar(t);
  }

  NavigationBar barra(WidgetTester t) =>
      t.widget<NavigationBar>(find.byType(NavigationBar));

  testWidgets('4 pestañas: Hoy, Medicinas, Semana y Más', (t) async {
    await abrir(t);
    for (final p in ['Hoy', 'Semana', 'Más']) {
      expect(find.text(p), findsOneWidget, reason: p);
    }
    expect(find.text('Rutinas'), findsNothing);
    expect(find.text('Historial'), findsNothing);
    expect(barra(t).selectedIndex, 0);
  });

  testWidgets('deslizar cambia de pestaña y la barra lo sigue', (t) async {
    await abrir(t);
    await t.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await t.pumpAndSettle();
    expect(barra(t).selectedIndex, 1);
    await t.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await t.pumpAndSettle();
    expect(barra(t).selectedIndex, 2);
    await t.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await t.pumpAndSettle();
    expect(barra(t).selectedIndex, 1);
  });

  testWidgets('tocar la barra lleva a la pestaña', (t) async {
    await abrir(t);
    await t.tap(find.text('Más'));
    await t.pumpAndSettle();
    expect(barra(t).selectedIndex, 3);
    expect(find.byType(PestanaMas), findsOneWidget);
  });

  testWidgets('el encabezado tiene llamar y Pregúntale a NANA', (t) async {
    await abrir(t);
    expect(find.byTooltip('Pregúntale a NANA'), findsOneWidget);
    // Rosa, de los datos de prueba, compartió su teléfono.
    expect(find.byTooltip('Llamar a Rosa'), findsOneWidget);
  });

  group('Más', () {
    Future<void> irAMas(WidgetTester t) async {
      await abrir(t);
      await t.tap(find.text('Más'));
      await t.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester t, String texto) async {
      // La lista de Más es larga: se baja (o sube) hasta el renglón.
      final lista = find
          .descendant(
            of: find.byType(PestanaMas),
            matching: find.byType(Scrollable),
          )
          .first;
      if (find.text(texto).evaluate().isEmpty) {
        await t.scrollUntilVisible(find.text(texto), 200, scrollable: lista);
      }
      // Al centro de la lista, para que la barra de pestañas no lo tape.
      await Scrollable.ensureVisible(
        t.element(find.text(texto)),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text(texto));
      await t.pumpAndSettle();
    }

    testWidgets('Los dos códigos están arriba en Más y funcionan', (t) async {
      await irAMas(t);
      expect(find.text('Códigos'), findsOneWidget);

      await tocar(t, 'Invitar a alguien de la familia');
      expect(find.text('Código de invitación'), findsOneWidget);
      await t.tapAt(const Offset(5, 5)); // cierra el diálogo
      await t.pumpAndSettle();

      // La pantalla del código tiene la mascota animada: no se «asienta».
      await Scrollable.ensureVisible(
        t.element(find.text('Código para el celular de Rosa')),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Código para el celular de Rosa'));
      await _esperar(t);
      expect(find.byType(PantallaCodigo), findsOneWidget);
    });

    testWidgets('abre Rutinas y Su expediente con su barra', (t) async {
      await irAMas(t);
      await tocar(t, 'Rutinas');
      expect(find.byType(PestanaRutinas), findsOneWidget);
      expect(find.text('Rutinas de Rosa'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await tocar(t, 'Su expediente');
      expect(find.byType(ResumenExpediente), findsOneWidget);
    });

    testWidgets('abre Familia y alertas y la Pantalla de Rosa', (t) async {
      await irAMas(t);
      await tocar(t, 'Familia y alertas');
      expect(find.byType(FamiliaAlertas), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await tocar(t, 'Pantalla de Rosa');
      expect(find.byType(PantallaDelAdulto), findsOneWidget);
    });

    testWidgets('Mis ajustes tiene la cuenta y cierra sesión', (t) async {
      // La huella era de esta cuenta: al salir se apaga.
      Ajustes.huellaActivada.value = true;
      Ajustes.huellaOfrecida.value = true;
      await irAMas(t);
      await tocar(t, 'Mis ajustes y cuenta');
      expect(find.byType(MisAjustes), findsOneWidget);
      expect(find.text('Cuidar a otra persona'), findsOneWidget);
      expect(find.text('Código para el celular de Rosa'), findsOneWidget);
      // Queda abajo de la lista: se baja hasta verlo.
      await t.scrollUntilVisible(
        find.text('Cerrar sesión'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(MisAjustes),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.tap(find.text('Cerrar sesión'));
      await t.pumpAndSettle();
      expect(Servicios.repo.uid, isNull);
      expect(find.byType(Bienvenida), findsOneWidget);
      expect(Ajustes.huellaActivada.value, isFalse);
      expect(Ajustes.huellaOfrecida.value, isFalse);
      // La bienvenida deja un temporizador.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 10));
    });
  });
}
