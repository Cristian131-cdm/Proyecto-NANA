import 'dart:typed_data';

// Fotos de recetas. Se quedan SOLO en el celular de quien las tomó: nunca
// suben a la nube y los demás familiares no las ven. A Firestore solo va el
// texto que la familia confirma (ver PantallaPrivacidad).
abstract class FotosLocales {
  // false en la web: ahí no hay dónde guardarlas sin subirlas.
  bool get disponible;

  // Abre el selector del celular. null si la persona canceló.
  Future<Uint8List?> elegir();
  Future<void> guardar(String id, Uint8List bytes);
  Future<Uint8List?> leer(String id);
  Future<void> borrar(String id);
}

const tamanoMaximoFoto = 10 * 1024 * 1024; // 10 MB

class FotoMuyGrande implements Exception {}

class SinFotos implements FotosLocales {
  const SinFotos();
  @override
  bool get disponible => false;
  @override
  Future<Uint8List?> elegir() async => null;
  @override
  Future<void> guardar(String id, Uint8List bytes) async {}
  @override
  Future<Uint8List?> leer(String id) async => null;
  @override
  Future<void> borrar(String id) async {}
}

// Para las pruebas: lo que "elige" la persona se pone en [siguiente].
class FotosEnMemoria implements FotosLocales {
  final guardadas = <String, Uint8List>{};
  Uint8List? siguiente;

  @override
  bool get disponible => true;
  @override
  Future<Uint8List?> elegir() async => siguiente;
  @override
  Future<void> guardar(String id, Uint8List bytes) async =>
      guardadas[id] = bytes;
  @override
  Future<Uint8List?> leer(String id) async => guardadas[id];
  @override
  Future<void> borrar(String id) async => guardadas.remove(id);
}
