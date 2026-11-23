import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/platica.dart';
import 'package:nana_app/core/voz.dart';

// Las urgencias tienen que funcionar aunque la laptop del agente esté
// apagada: la app las reconoce sola. Esta prueba lee la lista URGENCIA del
// agente en Python y revisa que la app reconozca cada una, para que las dos
// listas no se separen si alguien agrega una en un solo lado.
List<String> _urgenciasDelAgente() {
  final reglas = File('agente/nana_agente/reglas.py').readAsStringSync();
  final bloque = RegExp(r'URGENCIA = \(([\s\S]*?)\n\)').firstMatch(reglas)!;
  return [
    for (final m in RegExp(r'"([^"]+)"').allMatches(bloque.group(1)!))
      m.group(1)!,
  ];
}

void main() {
  test('la lista del agente se puede leer', () {
    expect(_urgenciasDelAgente(), contains('no me puedo levantar'));
    expect(_urgenciasDelAgente().length, greaterThan(20));
  });

  test('la app reconoce todas las urgencias del agente, sin la laptop', () {
    final faltan = [
      for (final f in _urgenciasDelAgente())
        if (entender(f, comandosAdulto) != 'Necesito ayuda') f,
    ];
    expect(faltan, isEmpty, reason: 'Agrégalas a comandosAdulto en platica.dart');
  });

  test('dentro de una frase también cuentan', () {
    for (final f in [
      'ay, no me puedo levantar',
      'me duele mucho el pecho, me duele el pecho',
      'creo que huele a gas en la cocina',
      'ayúdame por favor',
    ]) {
      expect(entender(f, comandosAdulto), 'Necesito ayuda', reason: f);
    }
  });

  test('en la plática abren la cuenta regresiva', () {
    final r = respuestaAdulto(
      'no me puedo levantar',
      nombre: 'Rosa',
      queSigue: () => '',
      ahora: DateTime(2026, 11, 23, 10),
    );
    expect(r.accion, AccionPlatica.ayuda);
  });

  test('«me siento muy mal» es urgencia; «me siento mal» se le cuenta a la familia', () {
    expect(entender('me siento muy mal', comandosAdulto), 'Necesito ayuda');
    expect(entender('me siento mal', comandosAdulto), 'Me siento mal');
  });
}
