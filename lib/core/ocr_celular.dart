import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'ocr_receta.dart';
import 'preprocesar_foto.dart';

OcrReceta crearOcr() =>
    defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS
    ? OcrCelular()
    : const OcrNulo();

class OcrCelular implements OcrReceta {
  @override
  bool get disponible => true;

  @override
  Future<String?> fotoYTexto() async {
    final foto = await ImagePicker().pickImage(source: ImageSource.camera);
    if (foto == null) return null;
    final dir = await getTemporaryDirectory();
    final lista = File('${dir.path}/receta_para_leer.png');
    final lector = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      // Preprocesar en otro hilo: con fotos de 12 MP tarda ~1 s.
      final bytes = await foto.readAsBytes();
      final preparada = await compute(prepararFoto, bytes);
      await lista.writeAsBytes(preparada ?? bytes);
      final leido = await lector.processImage(
        InputImage.fromFilePath(lista.path),
      );
      return leido.text;
    } finally {
      await lector.close();
      // Ni la foto ni la copia procesada se quedan guardadas.
      if (await lista.exists()) await lista.delete();
      try {
        await File(foto.path).delete();
      } catch (_) {}
    }
  }
}
