import 'package:flutter/material.dart';

/// El logo de NANA: la misma imagen del ícono de la app, sin el fondo
/// (sale de design/icono_c_2026-11-12). Es una imagen fija, para donde NANA aparece como marca. Donde NANA
/// está "viva" (inicio, recordatorio, hablar) se usa MascotaNana, que es el
/// mismo diseño dibujado con código y animado.
class LogoNana extends StatelessWidget {
  final double tamano;
  const LogoNana({super.key, this.tamano = 140});

  static const archivo = 'assets/logo/nana_c.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    archivo,
    width: tamano,
    height: tamano,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
