import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nana_app/widgets/aviso.dart';

void main() {
  for (final conDeshacer in [true, false]) {
    testWidgets(
      'el aviso ${conDeshacer ? 'con' : 'sin'} «Deshacer» se quita solo',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => mostrarAviso(
                    context,
                    'Borré Loratadina',
                    onDeshacer: conDeshacer ? () {} : null,
                  ),
                  child: const Text('borrar'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('borrar'));
        await t.pump();
        expect(find.text('Borré Loratadina'), findsOneWidget);
        // Primero termina de entrar (ahí empieza a contar), luego sus 5 s.
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 6));
        await t.pumpAndSettle();
        expect(find.text('Borré Loratadina'), findsNothing);
      },
    );
  }
}
