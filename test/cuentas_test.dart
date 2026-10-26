import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/screens/bienvenida.dart';

Future<void> _escribir(WidgetTester t, String etiqueta, String texto) async {
  final campo = find.widgetWithText(TextField, etiqueta);
  await t.ensureVisible(campo);
  await t.enterText(campo, texto);
}

Future<void> _tocar(WidgetTester t, String texto) async {
  await t.ensureVisible(find.text(texto));
  await t.pumpAndSettle();
  await t.tap(find.text(texto));
  await t.pumpAndSettle();
}

Future<void> _crearCuentaDeAna(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: Bienvenida()));
  await _tocar(t, 'Soy cuidador o familiar');
  await _tocar(t, 'Crear cuenta');
  await _escribir(t, 'Nombre', 'Ana');
  await _escribir(t, 'Celular (10 números)', '5512345678');
  await _escribir(t, 'Correo', 'ana.nueva@gmail.com');
  await _escribir(t, 'Contraseña', 'secreto1');
  await _tocar(t, 'Crear mi cuenta');
}

void main() {
  late RepositorioMemoria repo;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    repo = RepositorioMemoria(sesion: null);
    Servicios.repo = repo;
  });

  testWidgets('El cuidador crea su cuenta, da de alta a Rosa y ve su código',
      (t) async {
    await _crearCuentaDeAna(t);
    expect(find.text('¿A quién vas a cuidar?'), findsOneWidget);

    await _escribir(t, 'Nombre', 'Rosa');
    await _tocar(t, 'mamá');
    await _tocar(t, 'Siguiente');
    expect(find.text('¿Rosa tiene celular propio?'), findsOneWidget);

    await t.tap(find.text('Sí, tiene celular'));
    // La pantalla del código tiene una ruedita de espera que no termina.
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Código para Rosa'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d{3} \d{3}$')), findsOneWidget);
  });

  testWidgets('Rosa entra con el código y queda conectada con Ana',
      (t) async {
    // Ana ya existe; genera el código desde su celular.
    final conAna = RepositorioMemoria();
    final codigo = await conAna.generarCodigo('rosa');
    await conAna.cerrarSesion();
    Servicios.repo = conAna;

    await t.pumpWidget(const MaterialApp(home: Bienvenida()));
    await _tocar(t, 'Soy adulto mayor');
    await _tocar(t, 'Entrar con un código');
    await t.enterText(find.byType(TextField), codigo.codigo);
    await _tocar(t, 'Entrar');

    expect(find.text('Hola, Rosa'), findsOneWidget);
    expect(find.textContaining('Te conectaste con Ana'), findsOneWidget);
  });

  testWidgets('Un código que no existe muestra un aviso amable', (t) async {
    await t.pumpWidget(const MaterialApp(home: Bienvenida()));
    await _tocar(t, 'Soy adulto mayor');
    await _tocar(t, 'Entrar con un código');
    await t.enterText(find.byType(TextField), '000000');
    await _tocar(t, 'Entrar');

    expect(find.text(errorCodigo), findsOneWidget);
  });

  testWidgets('El botón Entrar espera a tener 6 números', (t) async {
    await t.pumpWidget(const MaterialApp(home: Bienvenida()));
    await _tocar(t, 'Soy adulto mayor');
    await _tocar(t, 'Entrar con un código');
    await t.enterText(find.byType(TextField), '48291');
    await t.pump();

    final boton = t.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Entrar'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('Un cuidador sin adultos a cargo llega a dar de alta',
      (t) async {
    await repo.crearCuentaCuidador(
      nombre: 'Luis',
      apellidos: '',
      telefono: '5500000003',
      correo: 'luis@gmail.com',
      contrasena: 'secreto1',
    );
    await repo.cerrarSesion();

    await t.pumpWidget(const MaterialApp(home: Bienvenida()));
    await _tocar(t, 'Soy cuidador o familiar');
    await _tocar(t, 'Ya tengo cuenta');
    await _escribir(t, 'Correo', 'luis@gmail.com');
    await _escribir(t, 'Contraseña', 'secreto1');
    await _tocar(t, 'Entrar');

    expect(find.text('¿A quién vas a cuidar?'), findsOneWidget);
  });

  testWidgets('Rosa sin celular: Ana lleva su día desde su panel', (t) async {
    await _crearCuentaDeAna(t);
    await _escribir(t, 'Nombre', 'Rosa');
    await _tocar(t, 'mamá');
    await _tocar(t, 'Siguiente');
    await _tocar(t, 'No tiene');

    expect(find.text('Tú llevarás el día de Rosa'), findsOneWidget);
    final adultos = await repo.adultosACargo().first;
    expect(adultos.single.tieneCelular, isFalse);
  });
}
