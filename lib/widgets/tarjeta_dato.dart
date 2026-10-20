import 'package:flutter/material.dart';

import '../core/tema.dart';

// Piezas compartidas por las pestañas del cuidador.

class TituloSeccion extends StatelessWidget {
  final String texto;
  const TituloSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(texto,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}

class TarjetaDato extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Color color;
  final VoidCallback? onTap;

  const TarjetaDato({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.color = ColoresNana.morado,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ColoresNana.moradoClaro, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (subtitulo != null)
                        Text(subtitulo!,
                            style: const TextStyle(
                                fontSize: 15, color: Color(0xFF6B6485))),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: Color(0xFF8A82A3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BotonSecundario extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  const BotonSecundario({
    super.key,
    required this.icono,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icono),
        label: Text(texto),
        style: FilledButton.styleFrom(
          backgroundColor: ColoresNana.moradoClaro,
          foregroundColor: ColoresNana.morado,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
