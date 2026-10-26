import 'dart:math';

// Código de 6 números que el cuidador le pasa al adulto para vincular su celular.

// Quita espacios y guiones. Devuelve null si no quedan exactamente 6 dígitos.
String? normalizarCodigo(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^\d{6}$').hasMatch(limpio) ? limpio : null;
}

// '482913' → '482 913', más fácil de dictar por teléfono.
String formatearCodigo(String codigo) =>
    '${codigo.substring(0, 3)} ${codigo.substring(3)}';

String codigoAlAzar(Random r) => r.nextInt(1000000).toString().padLeft(6, '0');

const vigenciaCodigo = Duration(hours: 24);
