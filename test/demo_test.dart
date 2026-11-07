import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/semana.dart';
import 'package:nana_app/data/demo.dart';
import 'package:nana_app/data/repositorio_memoria.dart';

void main() {
  test('Los datos de demostración llenan la semana sin tocar hoy', () async {
    final ahora = DateTime(2026, 11, 8, 12);
    final repo = RepositorioMemoria(reloj: () => ahora);
    final n = await cargarDemo(repo, 'rosa', ahora);
    expect(n, greaterThan(0));

    final hoy = await repo.registrosDeHoy('rosa').first;
    expect(hoy, isEmpty);

    final dias = semana(
      meds: await repo.medicamentos('rosa').first,
      rutinas: await repo.rutinas('rosa').first,
      registros: await repo.registrosDesde('rosa', DateTime(2026, 11, 2)).first,
      hoy: ahora,
    );
    expect(dias.where((d) => d.completo).length, 5); // un día se le pasó
    expect(dias.where((d) => d.horaMal != null).length, 1);
    expect((await repo.citas('rosa').first).length, 2);
  });

  test('Cargar la demostración dos veces no duplica', () async {
    final ahora = DateTime(2026, 11, 8, 12);
    final repo = RepositorioMemoria(reloj: () => ahora);
    await cargarDemo(repo, 'rosa', ahora);
    final otra = await cargarDemo(repo, 'rosa', ahora);
    expect(otra, 0);
  });
}
