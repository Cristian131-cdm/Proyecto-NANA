import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../core/tema.dart';

// El nombre del encargado principal (quien dio de alta a la persona), para
// decirle al familiar quién cambia las cosas: «Las agrega y cambia Ana».
// Mientras carga, o si no se encuentra, dice «quien la cuida».
class ConEncargado extends StatelessWidget {
  final String folio;
  final String? creadoPor;
  final Widget Function(String nombre) builder;

  const ConEncargado({
    super.key,
    required this.folio,
    required this.creadoPor,
    required this.builder,
  });

  static const sinNombre = 'quien la cuida';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Servicios.repo.familiaDe(folio),
      builder: (context, snap) {
        var nombre = sinNombre;
        for (final f in snap.data ?? const []) {
          if (f.uid == creadoPor && f.nombre.trim().isNotEmpty) {
            nombre = f.nombre.trim().split(' ').first;
          }
        }
        return builder(nombre);
      },
    );
  }
}

// Recuadro lila con candado: «Sus medicinas … solo los cambia Ana».
class AvisoCandado extends StatelessWidget {
  final String texto;
  const AvisoCandado(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresNana.moradoClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            color: ColoresNana.tintaSuave,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 18, color: ColoresNana.tinta),
            ),
          ),
        ],
      ),
    );
  }
}
