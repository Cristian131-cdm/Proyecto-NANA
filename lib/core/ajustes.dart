import 'package:flutter/material.dart';

class Ajustes {
  static final ValueNotifier<double> escalaTexto = ValueNotifier(1.0);

  // La encuesta de apariencia solo se muestra la primera vez
  static bool encuestaHecha = false;

  // Cómo prefiere usar NANA. Por ahora solo se guardan; la voz, las señas,
  // el alto contraste y la vibración se conectan en la fase de funcionalidad.
  static final ValueNotifier<bool> queMeHable = ValueNotifier(false);
  static final ValueNotifier<bool> conSenas = ValueNotifier(false);
  static final ValueNotifier<bool> altoContraste = ValueNotifier(false);
  static final ValueNotifier<bool> avisoVibracion = ValueNotifier(false);
}
