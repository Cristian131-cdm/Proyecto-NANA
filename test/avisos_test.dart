import 'package:flutter_test/flutter_test.dart';

import 'package:nana_app/core/avisos.dart';
import 'package:nana_app/data/repositorio_memoria.dart';

class _AvisosFalsos implements Avisos {
  final mostrados = <String>[];
  @override
  Future<void> pedirPermiso() async {}
  @override
  Future<void> mostrar(int id, String titulo, String cuerpo) async =>
      mostrados.add(titulo);
}

void main() {
  test('Avisa de las alertas nuevas, no de las que ya estaban', () async {
    var ahora = DateTime(2026, 11, 8, 10);
    final repo = RepositorioMemoria(reloj: () => ahora);
    await repo.pedirAyuda('rosa'); // ya estaba antes de abrir el panel

    final avisos = _AvisosFalsos();
    final vigilante = VigilanteAlertas(
      avisos: avisos,
      nombre: 'Rosa',
      ahora: ahora,
    )..escuchar(repo.alertasSinAtender('rosa'));
    await Future<void>.delayed(Duration.zero);
    expect(avisos.mostrados, isEmpty);

    ahora = ahora.add(const Duration(minutes: 5));
    await repo.avisarFrase('rosa', 'Me duele algo');
    await Future<void>.delayed(Duration.zero);
    expect(avisos.mostrados, ['Rosa dijo: "Me duele algo"']);

    await repo.pedirAyuda('rosa');
    await Future<void>.delayed(Duration.zero);
    expect(avisos.mostrados.last, 'Rosa necesita ayuda');
    expect(avisos.mostrados.length, 2);

    vigilante.cancelar();
  });
}
