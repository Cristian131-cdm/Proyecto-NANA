import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'mascota_nana.dart';

// Piezas comunes de las pantallas de registro, para que todas se vean igual:
// la mascota arriba, un título grande y campos de letra grande.
class PantallaPaso extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final String? barra;

  const PantallaPaso({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.children,
    this.barra,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: barra == null ? null : Text(barra!)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            const Center(child: MascotaNana(tamano: 96)),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ],
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    );
  }
}

class CampoNana extends StatelessWidget {
  final TextEditingController controller;
  final String etiqueta;
  final TextInputType? teclado;
  final bool oculto;
  final String? error;
  final Iterable<String>? autollenado;
  final ValueChanged<String>? onChanged;

  const CampoNana({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.teclado,
    this.oculto = false,
    this.error,
    this.autollenado,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        obscureText: oculto,
        autofillHints: autollenado,
        onChanged: onChanged,
        textCapitalization: teclado == null
            ? TextCapitalization.words
            : TextCapitalization.none,
        style: const TextStyle(fontSize: 22),
        decoration: InputDecoration(
          labelText: etiqueta,
          labelStyle: const TextStyle(fontSize: 20),
          errorText: error,
          errorStyle: const TextStyle(fontSize: 16),
          errorMaxLines: 2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
        ),
      ),
    );
  }
}

// Error que se lee en voz alta con TalkBack en cuanto aparece.
class MensajeError extends StatelessWidget {
  final String texto;
  const MensajeError(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColoresNana.alertaClaro,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: ColoresNana.alerta, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: 18, color: ColoresNana.tinta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Botón principal que muestra una ruedita mientras espera a Firebase.
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool ocupado;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.ocupado = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: ocupado ? null : onPressed,
      child: ocupado
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : Text(texto, textAlign: TextAlign.center),
    );
  }
}

class BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotonSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 64),
        foregroundColor: ColoresNana.morado,
        side: const BorderSide(color: ColoresNana.lila, width: 2),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      child: Text(texto, textAlign: TextAlign.center),
    );
  }
}
