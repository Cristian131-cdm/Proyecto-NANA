import 'package:flutter_test/flutter_test.dart';
import 'package:nana_app/core/voz.dart';
import 'package:nana_app/models/apariencia.dart';

Map<String, String> v(String name, String locale, [Map<String, String>? mas]) =>
    {'name': name, 'locale': locale, ...?mas};

void main() {
  test('reconoce mujer y hombre en voces de Samsung y Google', () {
    expect(generoDeVoz(v('es-MX-SMTf00', 'es-MX')), 'mujer');
    expect(generoDeVoz(v('es-MX-SMTm00', 'es-MX')), 'hombre');
    expect(generoDeVoz(v('es-us-x-sfb-local', 'es-US')), 'mujer');
    expect(generoDeVoz(v('es-us-x-esf-network', 'es-US')), 'hombre');
    // Sin confirmar de oído: no se adivina.
    expect(generoDeVoz(v('es-us-x-esd-local', 'es-US')), isNull);
    expect(
      generoDeVoz(v('rara', 'es-MX', {'features': 'gender=female'})),
      'mujer',
    );
    expect(
      generoDeVoz(v('rara', 'es-MX', {'features': 'gender=male'})),
      'hombre',
    );
    expect(generoDeVoz(v('es-mx-language', 'es-MX')), isNull);
  });

  test('prefiere México y sin internet', () {
    final voces = [
      v('en-us-x-iom-local', 'en-US'),
      v('es-us-x-esf-network', 'es-US', {'network_required': '1'}),
      v('es-us-x-esf-local', 'es-US', {'network_required': '0'}),
      v('es-MX-SMTm00', 'es-MX'),
      v('es-MX-SMTf00', 'es-MX'),
    ];
    expect(elegirVoz(voces, 'hombre')!['name'], 'es-MX-SMTm00');
    expect(elegirVoz(voces, 'mujer')!['name'], 'es-MX-SMTf00');
    expect(
      elegirVoz(
        voces.where((x) => !x['name']!.contains('SMT')).toList(),
        'hombre',
      )!['name'],
      'es-us-x-esf-local',
    );
  });

  test('no elige voces sin descargar (hablan en silencio)', () {
    final voces = [
      v('es-us-x-esf-local', 'es-US', {'features': '[notInstalled]'}),
      v('es-us-x-esf-network', 'es-US', {'features': '[networkTimeoutMs]'}),
    ];
    expect(elegirVoz(voces, 'hombre')!['name'], 'es-us-x-esf-network');
    expect(elegirVoz(voces.take(1).toList(), 'hombre'), isNull);
  });

  test('sin voz de ese género regresa null (la app baja el tono)', () {
    expect(elegirVoz([v('es-us-x-sfb-local', 'es-US')], 'hombre'), isNull);
    expect(elegirVoz([v('en-us-x-iom-local', 'en-US')], 'mujer'), isNull);
  });

  test('la voz viaja en la apariencia que manda el encargado', () {
    final a = const Apariencia().copyWith(vozNana: 'hombre');
    expect(Apariencia.deMapa(a.aMapa())!.vozNana, 'hombre');
    expect(Apariencia.deMapa({})!.vozNana, 'mujer');
  });
}
