import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nana_app/core/alarmas.dart';
import 'package:nana_app/core/avisos.dart';
import 'package:nana_app/models/alerta.dart';
import 'package:nana_app/models/medicamento.dart';

const losartan = Medicamento(
  id: 'm1',
  nombre: 'Losartán',
  dosis: '50 mg',
  hora: TimeOfDay(hour: 8, minute: 0),
  ventanaMin: 30,
);

class _AvisosFalsos implements Avisos {
  final List<String> titulos = [];
  @override
  Future<void> pedirPermiso() async {}
  @override
  Future<void> mostrar(int id, String titulo, String cuerpo) async =>
      titulos.add(titulo);
}

void main() {
  test('«ya se pasó» = la hora más la ventana', () {
    expect(
      cuandoPasada(losartan, DateTime(2026, 11, 25, 7)),
      DateTime(2026, 11, 25, 8, 30),
    );
    expect(
      textoPasada('Rosa', losartan),
      'Rosa, ya pasó la hora de tu Losartán. ¿Ya te la tomaste?',
    );
  });

  test('con la app abierta NANA avisa a la hora y al pasar la ventana, '
      'una vez cada una', () {
    final avisado = <String>{};
    DateTime a(int h, int m, [int s = 0]) => DateTime(2026, 11, 25, h, m, s);

    expect(medicinaQueAvisar([losartan], {}, a(7, 59), avisado), isNull);
    expect(medicinaQueAvisar([losartan], {}, a(8, 0, 20), avisado), losartan);
    expect(medicinaQueAvisar([losartan], {}, a(8, 0, 50), avisado), isNull);
    expect(medicinaQueAvisar([losartan], {}, a(8, 10), avisado), isNull);
    expect(medicinaQueAvisar([losartan], {}, a(8, 30, 10), avisado), losartan);
    expect(medicinaQueAvisar([losartan], {}, a(8, 30, 40), avisado), isNull);
  });

  test('si ya se la tomó, NANA no pregunta', () {
    expect(
      medicinaQueAvisar([losartan], {'m1'}, DateTime(2026, 11, 25, 8), {}),
      isNull,
    );
  });

  test('quien cuida oye a NANA decir la alerta nueva', () async {
    final alertas = StreamController<List<Alerta>>();
    final dicho = <String>[];
    final avisos = _AvisosFalsos();
    final ahora = DateTime(2026, 11, 25, 10);
    VigilanteAlertas(
      avisos: avisos,
      nombre: 'Rosa',
      ahora: ahora,
      decir: (t) async => dicho.add(t),
    ).escuchar(alertas.stream);

    alertas.add([]);
    await Future<void>.delayed(Duration.zero);
    alertas.add([
      Alerta(
        id: 'a1',
        fecha: ahora.add(const Duration(minutes: 1)),
        tipo: 'ayuda',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(avisos.titulos, ['Rosa necesita ayuda']);
    expect(dicho, ['Atención. Rosa necesita ayuda. Llámale.']);
    await alertas.close();
  });
}
