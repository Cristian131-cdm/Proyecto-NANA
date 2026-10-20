import 'package:flutter/material.dart';

class Ajustes {
  static final ValueNotifier<double> escalaTexto = ValueNotifier(1.0);

  // La encuesta de apariencia solo se muestra la primera vez
  static bool encuestaHecha = false;
}
