import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';

void main() {
  test('Lo que cambia se guarda en el celular', () async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    Ajustes.escalaTexto.value = 1.4;
    Ajustes.encuestaHecha.value = true;
    Ajustes.huellaActivada.value = true;
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('escala_texto'), 1.4);
    expect(prefs.getBool('encuesta_hecha'), isTrue);
    expect(prefs.getBool('huella_activada'), isTrue);
  });

  test('Al abrir la app se leen los ajustes guardados', () async {
    SharedPreferences.setMockInitialValues({
      'escala_texto': 1.6,
      'encuesta_hecha': true,
      'huella_ofrecida': true,
    });
    await Ajustes.cargar();

    expect(Ajustes.escalaTexto.value, 1.6);
    expect(Ajustes.encuestaHecha.value, isTrue);
    expect(Ajustes.huellaOfrecida.value, isTrue);
    expect(Ajustes.huellaActivada.value, isFalse);
  });
}
