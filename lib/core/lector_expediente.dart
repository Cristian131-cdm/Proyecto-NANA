import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/salud.dart';

typedef Archivo = ({String nombre, Uint8List bytes});

// Escoge el expediente (PDF o foto) y lo "lee" para llenar el formulario de
// salud. El documento nunca se sube ni se guarda: solo se guarda lo que la
// familia confirme después de revisarlo.
abstract class LectorExpediente {
  // true mientras NANA no lee el documento de verdad (sin IA todavía).
  bool get esSimulado;

  Future<Archivo?> elegir();
  Future<Salud> leer(Archivo archivo);
}

const tamanoMaximo = 10 * 1024 * 1024; // 10 MB

class ArchivoMuyGrande implements Exception {}

// Por decisión del equipo, por ahora no se llama a ninguna IA: después de una
// pausa regresa datos de ejemplo para enseñar cómo se revisan. Para leerlo de
// verdad se cambia esta clase por una que llame a la Cloud Function.
class LectorSimulado implements LectorExpediente {
  final Duration espera;
  const LectorSimulado({this.espera = const Duration(seconds: 2)});

  @override
  bool get esSimulado => true;

  @override
  Future<Archivo?> elegir() async {
    final elegidos = await FilePicker.pickFiles(
      dialogTitle: 'Escoge el expediente',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (elegidos.isEmpty) return null;
    final f = elegidos.first.xFile;
    if (await f.length() > tamanoMaximo) throw ArchivoMuyGrande();
    return (nombre: elegidos.first.name, bytes: await f.readAsBytes());
  }

  @override
  Future<Salud> leer(Archivo archivo) async {
    await Future<void>.delayed(espera);
    return const Salud(
      padecimientos: ['Hipertensión', 'Diabetes tipo 2'],
      alergias: ['Penicilina'],
      medicamentos: ['Losartán 50 mg', 'Metformina 850 mg'],
      origen: 'documento',
    );
  }
}
