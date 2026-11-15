import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'fotos_locales.dart';

FotosLocales crearFotos() => FotosEnDisco();

// Carpeta privada de la app en el celular. Android e iOS no dejan que otras
// apps la lean, y se borra al desinstalar NANA.
class FotosEnDisco implements FotosLocales {
  @override
  bool get disponible => true;

  Future<File> _archivo(String id) async {
    final base = await getApplicationDocumentsDirectory();
    final carpeta = Directory('${base.path}/recetas');
    if (!carpeta.existsSync()) carpeta.createSync(recursive: true);
    // El id viene de la app, pero por si acaso no se aceptan rutas.
    final limpio = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${carpeta.path}/$limpio.jpg');
  }

  @override
  Future<Uint8List?> elegir() async {
    final elegidos = await FilePicker.pickFiles(
      dialogTitle: 'Escoge la foto de la receta',
      type: FileType.image,
    );
    if (elegidos.isEmpty) return null;
    final f = elegidos.first.xFile;
    if (await f.length() > tamanoMaximoFoto) throw FotoMuyGrande();
    return f.readAsBytes();
  }

  @override
  Future<void> guardar(String id, Uint8List bytes) async =>
      (await _archivo(id)).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List?> leer(String id) async {
    final f = await _archivo(id);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<void> borrar(String id) async {
    final f = await _archivo(id);
    if (f.existsSync()) await f.delete();
  }
}
