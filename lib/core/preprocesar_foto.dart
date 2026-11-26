import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Preparar la foto de la receta antes del OCR (Modelado y Procesamiento de
// Imágenes). Los pasos se eligieron midiendo en el notebook
// `docs/receta_ocr/preprocesado_receta.ipynb` (separación letra/fondo en una
// receta sintética con luz despareja, sombra y ruido):
//   1. enderezar según la orientación de la cámara (EXIF),
//   2. reducir a 1600 px de ancho (más grande no lee mejor y tarda más),
//   3. escala de grises,
//   4. corregir la luz: dividir entre el fondo (cierre morfológico que borra
//      la letra y deja solo papel, luz y sombras),
//   5. estirar el contraste (del 2 % al 98 % del histograma).
// Medido: sin nada 4.1 · contraste solo 3.2 · Otsu 1.3 · umbral adaptativo
// 5.9 · luz + contraste 9–13. Suavizar no ayudó, así que no se usa.
// La foto procesada se queda en el celular, igual que la original.

const anchoMaximo = 1600;

class PasosPreprocesado {
  final bool enderezar;
  final bool reducir;
  final bool grises;
  final bool luz;
  final bool contraste;
  const PasosPreprocesado({
    this.enderezar = true,
    this.reducir = true,
    this.grises = true,
    this.luz = true,
    this.contraste = true,
  });
}

// Devuelve PNG listo para el OCR, o null si los bytes no son una imagen.
Uint8List? prepararFoto(
  Uint8List bytes, {
  PasosPreprocesado pasos = const PasosPreprocesado(),
}) {
  var foto = img.decodeImage(bytes);
  if (foto == null) return null;
  if (pasos.enderezar) foto = img.bakeOrientation(foto);
  if (pasos.reducir && foto.width > anchoMaximo) {
    foto = img.copyResize(foto, width: anchoMaximo);
  }
  if (pasos.grises) foto = img.grayscale(foto);
  if (pasos.luz) foto = corregirLuz(foto);
  if (pasos.contraste) foto = estirarContraste(foto);
  return img.encodePng(foto);
}

// El fondo se calcula sobre la foto chiquita (400 px) para que sea rápido en
// el celular, y se vuelve a agrandar. [ventana] = lado del cuadro del cierre.
img.Image corregirLuz(img.Image foto, {int chico = 400, int ventana = 11}) {
  final mini = img.copyResize(
    foto,
    width: chico,
    interpolation: img.Interpolation.average,
  );
  final w = mini.width, h = mini.height;
  final gris = List<int>.generate(
    w * h,
    (i) => img.getLuminance(mini.getPixel(i % w, i ~/ w)).round(),
  );
  // Cierre = dilatar (máximo) y luego erosionar (mínimo): la letra oscura y
  // delgada desaparece y queda el papel con su luz y sus sombras.
  final fondoMini = _filtro(
    _filtro(gris, w, h, ventana, math.max),
    w,
    h,
    ventana,
    math.min,
  );
  final fondoImg = img.Image(width: w, height: h, numChannels: 1);
  for (var i = 0; i < fondoMini.length; i++) {
    fondoImg.setPixelR(i % w, i ~/ w, fondoMini[i]);
  }
  final fondo = img.copyResize(
    fondoImg,
    width: foto.width,
    height: foto.height,
    interpolation: img.Interpolation.linear,
  );
  for (final p in foto) {
    final f = math.max(fondo.getPixel(p.x, p.y).r.toDouble(), 1);
    final v = (img.getLuminance(p) / f * 255).round().clamp(0, 255);
    p
      ..r = v
      ..g = v
      ..b = v;
  }
  return foto;
}

// Máximo o mínimo en un cuadro de lado [k] (separable: renglones y columnas).
List<int> _filtro(List<int> v, int w, int h, int k, int Function(int, int) op) {
  final r = k ~/ 2;
  final tmp = List<int>.filled(v.length, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = v[y * w + x];
      for (var d = -r; d <= r; d++) {
        final xx = x + d;
        if (xx >= 0 && xx < w) m = op(m, v[y * w + xx]);
      }
      tmp[y * w + x] = m;
    }
  }
  final out = List<int>.filled(v.length, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = tmp[y * w + x];
      for (var d = -r; d <= r; d++) {
        final yy = y + d;
        if (yy >= 0 && yy < h) m = op(m, tmp[yy * w + x]);
      }
      out[y * w + x] = m;
    }
  }
  return out;
}

// Lleva el 2 % más oscuro a negro y el 2 % más claro a blanco: una receta
// tomada con poca luz queda con letras oscuras sobre fondo claro.
img.Image estirarContraste(img.Image foto, {double recorte = 0.02}) {
  final histograma = List<int>.filled(256, 0);
  for (final p in foto) {
    histograma[img.getLuminance(p).round().clamp(0, 255)]++;
  }
  final total = foto.width * foto.height;
  int buscar(double fraccion) {
    var suma = 0;
    for (var i = 0; i < 256; i++) {
      suma += histograma[i];
      if (suma >= total * fraccion) return i;
    }
    return 255;
  }

  final bajo = buscar(recorte);
  final alto = buscar(1 - recorte);
  if (alto - bajo < 10) return foto; // ya está plana: no se toca
  final escala = 255 / (alto - bajo);
  for (final p in foto) {
    int estira(num v) => ((v - bajo) * escala).round().clamp(0, 255);
    p
      ..r = estira(p.r)
      ..g = estira(p.g)
      ..b = estira(p.b);
  }
  return foto;
}
