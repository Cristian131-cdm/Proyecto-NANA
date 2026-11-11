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
      child: Semantics(
        header: true,
        child: Text(
          texto,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class TarjetaDato extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Color color;
  final VoidCallback? onTap;
  final Widget? accion;

  const TarjetaDato({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.color = ColoresNana.morado,
    this.onTap,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: ColoresNana.moradoClaro),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitulo!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: ColoresNana.tintaSuave,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (accion != null) ...[
                  const SizedBox(width: 8),
                  accion!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: ColoresNana.morado),
                ],
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
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icono),
      label: Text(texto, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        backgroundColor: ColoresNana.moradoClaro,
        foregroundColor: ColoresNana.morado,
        minimumSize: const Size(0, 64),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class CabeceraCuidador extends StatelessWidget {
  final String titulo;
  final String detalle;
  final IconData icono;
  const CabeceraCuidador({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: ColoresNana.moradoClaro,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icono, color: ColoresNana.morado, size: 28),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detalle,
                style: const TextStyle(
                  fontSize: 16,
                  color: ColoresNana.tintaSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Las tarjetas y acciones pasan a una columna al crecer la letra.
class ColumnasCuidador extends StatelessWidget {
  final List<Widget> children;
  final double anchoMinimo;
  final int maxColumnas;
  const ColumnasCuidador({
    super.key,
    required this.children,
    this.anchoMinimo = 160,
    this.maxColumnas = 2,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final escala = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columnas = ((limites.maxWidth + 12) / (anchoMinimo * escala + 12))
          .floor()
          .clamp(1, maxColumnas);
      final ancho = (limites.maxWidth - 12 * (columnas - 1)) / columnas;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: ancho, child: child),
        ],
      );
    },
  );
}

class SuperficieCuidador extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SuperficieCuidador({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: ColoresNana.moradoClaro),
    ),
    child: child,
  );
}
