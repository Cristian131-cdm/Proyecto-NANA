import 'package:flutter/material.dart';

import 'core/ajustes.dart';
import 'core/avisos.dart';
import 'core/senas/ojo_sin_camara.dart'
    if (dart.library.io) 'core/senas/ojo_camara.dart';
import 'core/servicios.dart';
import 'core/voz.dart';
import 'data/demo.dart';
import 'data/repositorio_memoria.dart';
import 'main.dart';
import 'screens/candado.dart';
import 'screens/recordatorio_alarma.dart';

// Plan B para presentar sin internet: los datos viven en la memoria del
// celular (o del navegador) y se pierden al cerrar. No usa Firebase.
//   Cuidadora (Ana):  flutter run -t lib/main_demo.dart
//   Adulto (Rosa):    flutter run -t lib/main_demo.dart --dart-define=ROL=adulto
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const rol = String.fromEnvironment('ROL', defaultValue: 'cuidador');
  final repo = RepositorioMemoria(sesion: rol == 'adulto' ? 'rosa-cel' : 'ana');
  await cargarDemo(repo, 'rosa', DateTime.now());
  Servicios.repo = repo;
  Servicios.avisos = AvisosLocales();
  Servicios.voz = VozCelular();
  Servicios.crearOjo = crearOjoCamara;
  await Ajustes.cargar();
  VigilanteCandado.instancia.iniciar();
  await Servicios.alarmas.iniciar(abrirDesdeAlarma);
  runApp(const NanaApp());
}
