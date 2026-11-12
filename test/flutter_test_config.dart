import 'dart:async';

import 'package:nana_app/widgets/mascota_nana.dart';

// Corre antes de cada archivo de pruebas. La mascota se anima sin parar, y
// eso no deja terminar a pumpAndSettle: en pruebas se queda quieta.
Future<void> testExecutable(FutureOr<void> Function() pruebas) async {
  MascotaNana.vive = false;
  await pruebas();
}
