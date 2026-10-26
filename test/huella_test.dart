import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/biometria.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/entrar_con_codigo.dart';

class _BiometriaFalsa implements Biometria {
  final bool hay;
  int intentos = 0;
  _BiometriaFalsa({required this.hay});

  @override
  Future<bool> disponible() async => hay;

  @override
  Future<bool> autenticar(String motivo) async {
    intentos++;
    return true;
  }
}

Future<void> _entrarConCodigo(WidgetTester t) async {
  final repo = RepositorioMemoria();
  final codigo = await repo.generarCodigo('rosa');
  await repo.cerrarSesion();
  Servicios.repo = repo;
  await t.pumpWidget(const SizedBox()); // empieza sin pantallas viejas
  await t.pumpWidget(const MaterialApp(home: EntrarConCodigo()));
  await t.enterText(find.byType(TextField), codigo.codigo);
  await t.pump();
  await t.tap(find.text('Entrar'));
  await t.pumpAndSettle();
  await t.tap(find.text('Continuar'));
  await t.pumpAndSettle();
}

void main() {
  final las9 = DateTime(2026, 10, 26, 9);

  group('Cuándo se pide la huella', () {
    bool pedir({
      bool activada = true,
      Duration? fuera,
      bool alarma = false,
    }) => hayQuePedirHuella(
      activada: activada,
      enSegundoPlanDesde: fuera == null ? null : las9.subtract(fuera),
      ahora: las9,
      vieneDeAlarma: alarma,
    );

    test('a los 29 minutos todavía no', () {
      expect(pedir(fuera: const Duration(minutes: 29)), isFalse);
    });
    test('a los 30 minutos sí', () {
      expect(pedir(fuera: const Duration(minutes: 30)), isTrue);
    });
    test('al abrir la app en frío sí', () {
      expect(pedir(), isTrue);
    });
    test('desde la alarma de la medicina nunca', () {
      expect(pedir(alarma: true), isFalse);
      expect(pedir(alarma: true, fuera: const Duration(hours: 5)), isFalse);
    });
    test('si está desactivada nunca', () {
      expect(pedir(activada: false), isFalse);
    });
  });

  group('Recomendación de la huella', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Ajustes.cargar();
      Ajustes.encuestaHecha.value = true;
    });
    tearDown(() => Servicios.biometria = BiometriaLocal());

    testWidgets('Al vincularse se ofrece la huella una sola vez', (t) async {
      Servicios.biometria = _BiometriaFalsa(hay: true);
      await _entrarConCodigo(t);
      expect(find.text('¿Quieres entrar con tu huella?'), findsOneWidget);

      await t.ensureVisible(find.text('Ahora no'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ahora no'));
      await t.pumpAndSettle();
      expect(Ajustes.huellaOfrecida.value, isTrue);
      expect(Ajustes.huellaActivada.value, isFalse);

      await _entrarConCodigo(t);
      expect(find.text('¿Quieres entrar con tu huella?'), findsNothing);
    });

    testWidgets('"Sí, activarla" pide la huella y la deja encendida',
        (t) async {
      final bio = _BiometriaFalsa(hay: true);
      Servicios.biometria = bio;
      await _entrarConCodigo(t);
      await t.ensureVisible(find.text('Sí, activarla'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sí, activarla'));
      await t.pumpAndSettle();

      expect(bio.intentos, 1);
      expect(Ajustes.huellaActivada.value, isTrue);
    });

    testWidgets('Sin huella ni PIN en el celular no se ofrece', (t) async {
      Servicios.biometria = _BiometriaFalsa(hay: false);
      await _entrarConCodigo(t);
      expect(find.text('¿Quieres entrar con tu huella?'), findsNothing);
    });
  });
}
