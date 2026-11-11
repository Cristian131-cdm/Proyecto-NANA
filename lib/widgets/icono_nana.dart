import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/tema.dart';
import '../models/actividad.dart';

// Íconos propios de NANA (diseño B, assets/iconos/). Son SVG de un solo
// color: se pintan con el color que se les pase (siempre de ColoresNana), así
// que funcionan con "Colores más fuertes" y crecen sin verse borrosos.
enum IconoB {
  pastilla,
  hablar,
  familia,
  miDia,
  ayuda,
  nana,
  comida,
  caminar,
  animo,
  llamar,
  senas;

  String get ruta => switch (this) {
    IconoB.miDia => 'assets/iconos/mi_dia.svg',
    _ => 'assets/iconos/$name.svg',
  };
}

class IconoNana extends StatelessWidget {
  final IconoB icono;
  final double tamano;
  final Color? color;
  // Solo si el ícono va solo, sin texto al lado. Si hay texto visible, el
  // lector ya lo dice y el dibujo no se anuncia (para no repetir).
  final String? etiqueta;

  const IconoNana(
    this.icono, {
    super.key,
    this.tamano = 24,
    this.color,
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? ColoresNana.morado;
    return SvgPicture.asset(
      icono.ruta,
      width: tamano,
      height: tamano,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: etiqueta,
      excludeFromSemantics: etiqueta == null,
    );
  }
}

extension TipoActividadIconoB on TipoActividad {
  IconoB? get iconoB => switch (this) {
    TipoActividad.medicina => IconoB.pastilla,
    TipoActividad.comida => IconoB.comida,
    TipoActividad.ejercicio => IconoB.caminar,
    TipoActividad.animo => IconoB.animo,
    TipoActividad.mensaje => null,
  };
}

// El ícono de una actividad: el propio de NANA si hay, si no el de Material.
class IconoActividad extends StatelessWidget {
  final TipoActividad tipo;
  final double tamano;
  final Color? color;
  const IconoActividad(this.tipo, {super.key, this.tamano = 24, this.color});

  @override
  Widget build(BuildContext context) => switch (tipo.iconoB) {
    final b? => IconoNana(b, tamano: tamano, color: color),
    null => Icon(tipo.icono, size: tamano, color: color),
  };
}
