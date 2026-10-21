// Genera los PNG del ícono y del splash a partir de MascotaNana, para que
// todo salga del mismo dibujo. No es una prueba: se corre a mano con
//   flutter test tool/generar_iconos.dart
// y después
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/tema.dart';
import 'package:nana_app/widgets/mascota_nana.dart';

Future<void> _guardar(
  WidgetTester tester, {
  required String archivo,
  required double lienzo,
  required double mascota,
  Color fondo = Colors.transparent,
}) async {
  final clave = GlobalKey();
  tester.view.physicalSize = Size(lienzo, lienzo);
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: clave,
        child: Container(
          width: lienzo,
          height: lienzo,
          color: fondo,
          alignment: Alignment.center,
          child: MascotaNana(tamano: mascota),
        ),
      ),
    ),
  );

  await tester.runAsync(() async {
    final limite =
        clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage();
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final f = File('assets/icono/$archivo');
    await f.create(recursive: true);
    await f.writeAsBytes(datos!.buffer.asUint8List());
  });
}

// Las pruebas no traen la fuente de íconos; sin ella el corazón sale como cuadro.
Future<void> _cargarIconos() async {
  final raiz = Platform.environment['FLUTTER_ROOT']!;
  final bytes = await File(
    '$raiz/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ).readAsBytes();
  final cargador = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await cargador.load();
}

void main() {
  setUpAll(_cargarIconos);

  testWidgets('Genera los PNG de NANA', (tester) async {
    // Ícono completo (iOS y Android viejo): no admite transparencia.
    await _guardar(
      tester,
      archivo: 'icono.png',
      lienzo: 1024,
      mascota: 760,
      fondo: ColoresNana.morado,
    );
    // Frente del ícono adaptable de Android: dentro de la zona segura.
    await _guardar(
      tester,
      archivo: 'icono_frente.png',
      lienzo: 1024,
      mascota: 560,
    );
    // Splash nativo: 640 px a 4x = 160 dp, igual que la mascota del splash animado.
    await _guardar(tester, archivo: 'splash.png', lienzo: 640, mascota: 640);
    // Splash de Android 12+: la imagen se recorta en un círculo de 2/3.
    await _guardar(
      tester,
      archivo: 'splash_android12.png',
      lienzo: 1152,
      mascota: 540,
    );

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
