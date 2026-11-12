import 'package:flutter/material.dart';

/// El logo de NANA: la ilustración del diseño B (la misma del ícono de la
/// app). Es una imagen fija, para donde NANA aparece como marca. Donde NANA
/// está "viva" (inicio, recordatorio, hablar) se usa MascotaNana, que es el
/// mismo diseño dibujado con código y animado.
class LogoNana extends StatelessWidget {
  final double tamano;
  const LogoNana({super.key, this.tamano = 140});

  // La ilustración deja ~12% de aire en cada lado.
  static const _aire = 0.76;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamano,
    height: tamano,
    child: OverflowBox(
      maxWidth: tamano / _aire,
      maxHeight: tamano / _aire,
      child: Image.asset(
        'assets/logo/nana.png',
        width: tamano / _aire,
        height: tamano / _aire,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}
