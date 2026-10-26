import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';

void main() {
  test('El código vincula el celular del adulto con su cuidador', () async {
    final repo = RepositorioMemoria(sesion: 'ana');
    final folio = await repo.altaAdulto(
      nombre: 'Ernesto',
      apellidos: 'López',
      parentesco: 'papá',
      tieneCelular: true,
    );
    final codigo = await repo.generarCodigo(folio);
    expect(await repo.codigoUsado(codigo.codigo).first, isFalse);

    await repo.cerrarSesion(); // ahora es el celular de Ernesto
    final adulto = await repo.canjearCodigo(codigo.codigo);

    expect(adulto.folio, folio);
    expect(adulto.uidAdulto, repo.uid);
    expect((await repo.adultoPropio())?.nombre, 'Ernesto');
    expect(await repo.codigoUsado(codigo.codigo).first, isTrue);
    expect(await repo.nombreDeCuidador(folio), 'Ana');
  });

  test('Un código solo sirve una vez', () async {
    final repo = RepositorioMemoria();
    final codigo = await repo.generarCodigo('rosa');
    await repo.canjearCodigo(codigo.codigo);

    expect(
      () => repo.canjearCodigo(codigo.codigo),
      throwsA(isA<ErrorNana>().having((e) => e.mensaje, 'mensaje', errorCodigo)),
    );
  });

  test('El código vence a las 24 horas', () async {
    var ahora = DateTime(2026, 10, 25, 9);
    final repo = RepositorioMemoria(reloj: () => ahora);
    final codigo = await repo.generarCodigo('rosa');
    ahora = ahora.add(const Duration(hours: 24, minutes: 1));

    expect(
      () => repo.canjearCodigo(codigo.codigo),
      throwsA(isA<ErrorNana>().having((e) => e.mensaje, 'mensaje', errorCodigo)),
    );
  });

  test('Pedir ayuda crea una alerta que el cuidador puede atender', () async {
    final repo = RepositorioMemoria();
    expect(await repo.pedirAyuda('rosa'), isTrue);

    final alertas = await repo.alertasSinAtender('rosa').first;
    expect(alertas, hasLength(1));

    await repo.atenderAlerta('rosa', alertas.single.id);
    expect(await repo.alertasSinAtender('rosa').first, isEmpty);
  });
}
