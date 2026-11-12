import 'ojo.dart';

// En la web no hay detector de manos: se usa esta versión, que solo dice
// que no hay cámara. (ojo_camara.dart no compila para web.)
OjoSenas crearOjoCamara() => OjoSinCamara();
