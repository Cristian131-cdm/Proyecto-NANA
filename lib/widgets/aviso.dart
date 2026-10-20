import 'package:flutter/material.dart';

void mostrarAviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 20))),
    );
}

// Para los botones que ya tienen lugar en la pantalla pero todavía no hacen nada.
void avisoPendiente(BuildContext context) =>
    mostrarAviso(context, 'Esto todavía no está disponible');
