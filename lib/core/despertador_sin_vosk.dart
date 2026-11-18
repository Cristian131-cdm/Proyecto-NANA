import 'despertador.dart';

// En la web no hay Vosk: se usa el reconocimiento del navegador.
Despertador crearDespertador() => DespertadorConVoz();
