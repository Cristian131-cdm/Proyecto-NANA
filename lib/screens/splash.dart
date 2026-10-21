import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/mascota_nana.dart';
import 'seleccion_rol.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _tamanoMascota = 160.0;

  // Línea de tiempo principal (la misma duración de antes) y un latido
  // que se repite para que la mascota flote y el halo "respire".
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final Animation<double> _subir = _tramo(0.0, 0.25, Curves.easeOutCubic);
  late final Animation<double> _halo = _tramo(0.05, 0.3, Curves.easeOut);
  late final Animation<double> _titulo = _tramo(0.2, 0.38, Curves.easeOut);
  late final Animation<double> _lema = _tramo(0.3, 0.46, Curves.easeOut);
  late final List<Animation<double>> _pilares = [
    _tramo(0.45, 0.6, Curves.easeOutBack),
    _tramo(0.55, 0.7, Curves.easeOutBack),
    _tramo(0.65, 0.8, Curves.easeOutBack),
  ];

  Animation<double> _tramo(double inicio, double fin, Curve curva) =>
      CurvedAnimation(
        parent: _c,
        curve: Interval(inicio, fin, curve: curva),
      );

  @override
  void initState() {
    super.initState();
    // Pequeña pausa para que la app termine de cargar antes de animar
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) _latido.repeat();
      _c.forward().then((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, _, _) => const SeleccionRol(),
            transitionsBuilder: (_, animacion, _, child) =>
                FadeTransition(opacity: animacion, child: child),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Con "reducir animaciones" se muestra todo quieto desde el inicio.
    final quieto = MediaQuery.disableAnimationsOf(context);
    double v(Animation<double> a) => quieto ? 1 : a.value;

    return Scaffold(
      body: DecoratedBox(
        // Arriba y al centro es el mismo color del splash del sistema,
        // así el paso de uno al otro no se nota.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColoresNana.fondo,
              ColoresNana.fondo,
              ColoresNana.moradoClaro,
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, caja) => AnimatedBuilder(
            animation: Listenable.merge([_c, _latido]),
            builder: (context, _) {
              final alto = caja.maxHeight;
              final ancho = caja.maxWidth;
              final onda = math.sin(_latido.value * 2 * math.pi);

              // La mascota empieza en el centro (donde la deja el splash
              // nativo) y sube a su lugar.
              final centroFinal = alto * 0.34;
              final centroY = lerpDouble(alto / 2, centroFinal, v(_subir))!;
              final flotar = quieto ? 0.0 : onda * 6 * v(_subir);
              final tamanoHalo = 250 + (quieto ? 0.0 : onda * 12);

              return Stack(
                children: [
                  Positioned(
                    left: (ancho - tamanoHalo) / 2,
                    top: centroY - tamanoHalo / 2,
                    child: Opacity(
                      opacity: v(_halo) * 0.9,
                      child: Container(
                        width: tamanoHalo,
                        height: tamanoHalo,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              ColoresNana.lila.withValues(alpha: 0.45),
                              ColoresNana.lila.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (ancho - _tamanoMascota) / 2,
                    top: centroY - _tamanoMascota / 2 + flotar,
                    child: const MascotaNana(tamano: _tamanoMascota),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: centroFinal + _tamanoMascota / 2 + 36,
                    child: Column(
                      children: [
                        _Aparecer(
                          valor: v(_titulo),
                          child: const Text(
                            'NANA',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: ColoresNana.morado,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _Aparecer(
                          valor: v(_lema),
                          child: const Text(
                            'Nunca Ausente, Nunca Abandonad@',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 88,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Pilar(
                          valor: v(_pilares[0]),
                          icono: Icons.favorite,
                          texto: 'Cuido',
                        ),
                        _Pilar(
                          valor: v(_pilares[1]),
                          icono: Icons.people_alt,
                          texto: 'Acompaño',
                        ),
                        _Pilar(
                          valor: v(_pilares[2]),
                          icono: Icons.shield,
                          texto: 'Protejo',
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: (ancho - 120) / 2,
                    bottom: 48,
                    child: Opacity(
                      opacity: v(_lema),
                      child: SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _c.value,
                            minHeight: 5,
                            backgroundColor: Colors.white,
                            color: ColoresNana.lila,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Entra subiendo un poco y apareciendo.
class _Aparecer extends StatelessWidget {
  final double valor;
  final Widget child;
  const _Aparecer({required this.valor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: valor.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - valor)),
        child: child,
      ),
    );
  }
}

class _Pilar extends StatelessWidget {
  final double valor;
  final IconData icono;
  final String texto;
  const _Pilar({required this.valor, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: valor.clamp(0, 1),
      child: Transform.scale(
        scale: 0.6 + 0.4 * valor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ColoresNana.lila, width: 2),
              ),
              child: Icon(icono, color: ColoresNana.morado, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ColoresNana.morado,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
