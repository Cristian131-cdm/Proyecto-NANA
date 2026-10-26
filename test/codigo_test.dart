import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/codigo.dart';

void main() {
  test('El código acepta espacios y guiones', () {
    expect(normalizarCodigo(' 482-913 '), '482913');
    expect(normalizarCodigo('482 913'), '482913');
  });

  test('El código necesita exactamente 6 números', () {
    expect(normalizarCodigo('48291'), isNull);
    expect(normalizarCodigo('4829130'), isNull);
    expect(normalizarCodigo('abc123'), isNull);
    expect(normalizarCodigo(''), isNull);
  });

  test('El código se muestra en dos grupos de tres', () {
    expect(formatearCodigo('012345'), '012 345');
  });

  test('Los códigos al azar siempre tienen 6 números', () {
    final r = Random(1);
    for (var i = 0; i < 100; i++) {
      expect(normalizarCodigo(codigoAlAzar(r)), isNotNull);
    }
  });
}
