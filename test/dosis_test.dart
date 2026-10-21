import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/screens/pestana_medicamentos.dart';

void main() {
  test('Acepta dosis bien escritas', () {
    for (final d in ['5', '50', '0.5', '0.25', '2.5', '1000']) {
      expect(errorDosis(d), isNull, reason: d);
    }
  });

  test('Pide cero antes del punto', () {
    expect(errorDosis('.5'), 'Pon un cero antes del punto: 0.5');
  });

  test('Rechaza el cero final', () {
    expect(errorDosis('5.0'), 'Quita el cero final: escribe 5');
    expect(errorDosis('2.50'), 'Quita el cero final: escribe 2.5');
  });

  test('Rechaza vacío, punto suelto, ceros al inicio y cero', () {
    expect(errorDosis(''), 'Escribe la dosis');
    expect(errorDosis('5.'), 'Termina el número o quita el punto');
    expect(errorDosis('05'), 'Quita el cero del inicio');
    expect(errorDosis('0'), 'La dosis debe ser mayor que cero');
  });
}
