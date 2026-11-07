import 'package:flutter/material.dart';

import '../core/tema.dart';

// En pantallas anchas (la web en una compu, una tablet acostada) NANA se ve
// como una columna centrada del ancho de un celular grande, para que los
// botones y las tarjetas no se estiren de lado a lado.
class MarcoAncho extends StatelessWidget {
  final Widget child;
  static const anchoMaximo = 560.0;

  const MarcoAncho({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ancho = mq.size.width;
    final angosto = ancho <= anchoMaximo + 120;
    // Mismo árbol en los dos casos para no recrear el navegador al girar o
    // cambiar el tamaño de la ventana.
    return ColoredBox(
      color: angosto ? ColoresNana.fondo : ColoresNana.moradoClaro,
      child: Center(
        child: SizedBox(
          width: angosto ? ancho : anchoMaximo,
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(angosto ? ancho : anchoMaximo, mq.size.height),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: angosto
                    ? const []
                    : [
                        BoxShadow(
                          color: ColoresNana.morado.withValues(alpha: 0.12),
                          blurRadius: 32,
                        ),
                      ],
              ),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
