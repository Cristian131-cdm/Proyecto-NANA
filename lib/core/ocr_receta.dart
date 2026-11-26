// Tomar la foto de la receta y leer su texto DENTRO del celular (ML Kit, sin
// internet). Ni la foto ni el texto se guardan en la nube: el texto solo va
// al agente para armar la lista que la familia confirma.
abstract class OcrReceta {
  bool get disponible;
  // Abre la cámara; null si la persona cancela.
  Future<String?> fotoYTexto();
}

// En web y en pruebas: no hay cámara.
class OcrNulo implements OcrReceta {
  const OcrNulo();
  @override
  bool get disponible => false;
  @override
  Future<String?> fotoYTexto() async => null;
}

// Para las pruebas: «lee» el texto que se le da.
class OcrFalso implements OcrReceta {
  final String? texto;
  const OcrFalso(this.texto);
  @override
  bool get disponible => true;
  @override
  Future<String?> fotoYTexto() async => texto;
}
