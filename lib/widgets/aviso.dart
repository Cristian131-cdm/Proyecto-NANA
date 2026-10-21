import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

// Abre el marcador del teléfono con el número listo; la persona decide si llama.
// En web o en un emulador sin teléfono, al menos muestra el número.
Future<void> llamar(BuildContext context, String telefono) async {
  final abierto = await launchUrl(Uri(scheme: 'tel', path: telefono))
      .catchError((_) => false);
  if (!abierto && context.mounted) {
    mostrarAviso(context, 'No se pudo abrir el teléfono. Número: $telefono');
  }
}
