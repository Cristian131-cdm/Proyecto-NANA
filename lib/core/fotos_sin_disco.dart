import 'fotos_locales.dart';

// En la web no hay carpeta privada: NANA no guarda fotos ahí.
// (fotos_disco.dart usa dart:io y no compila para web.)
FotosLocales crearFotos() => const SinFotos();
