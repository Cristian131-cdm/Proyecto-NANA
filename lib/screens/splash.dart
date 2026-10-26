import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/mascota_nana.dart';
import 'arranque.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _tamanoMascota = 160.0;

  // Línea de tiempo de 6 s (más la pausa inicial de 0.4 s):
  //   0.0 – 0.8  la mascota rebota y sube; se abre el halo
  //   0.9 – 1.4  parpadea y el corazón late una vez
  //   1.4 – 2.6  N · A · N · A, letra por letra
  //   2.6 – 3.4  el lema
  //   3.4 – 4.6  Cuido, Acompaño, Protejo
  //   4.6 – 6.0  pausa: todo quieto, solo late el corazón
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  );
  // Se repite todo el tiempo: la mascota flota y el corazón late.
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _rebote = _tramo(0.0, 0.1, Curves.linear);
  late final Animation<double> _subir = _tramo(0.05, 0.13, Curves.easeOutCubic);
  late final Animation<double> _halo = _tramo(0.03, 0.15, Curves.easeOut);
  late final Animation<double> _parpadeo = _tramo(0.15, 0.2, Curves.linear);
  late final Animation<double> _corazon = _tramo(0.18, 0.24, Curves.linear);
  late final List<Animation<double>> _letras = [
    for (var i = 0; i < 4; i++)
      _tramo(0.23 + i * 0.05, 0.31 + i * 0.05, Curves.easeOutBack),
  ];
  late final Animation<double> _lema = _tramo(0.44, 0.56, Curves.easeOut);
  late final List<Animation<double>> _pilares = [
    _tramo(0.57, 0.65, Curves.easeOut),
    _tramo(0.63, 0.71, Curves.easeOut),
    _tramo(0.69, 0.77, Curves.easeOut),
  ];
  late final Animation<double> _pausa = _tramo(0.77, 0.82, Curves.easeIn);
  late final Animation<double> _pista = _tramo(0.25, 0.35, Curves.easeOut);

  bool _salio = false;

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
      if (!mounted || _salio) return;
      if (!MediaQuery.disableAnimationsOf(context)) _latido.repeat();
      _c.forward().then((_) => _irARol());
    });
  }

  // Al terminar, o antes si la persona toca la pantalla.
  void _irARol() {
    if (!mounted || _salio) return;
    _salio = true;
    _c.stop();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const Arranque(),
        transitionsBuilder: (_, animacion, _, child) =>
            FadeTransition(opacity: animacion, child: child),
      ),
    );
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
    // Sube y baja una sola vez dentro de su tramo (0 → 1 → 0).
    double pico(Animation<double> a) =>
        quieto ? 0 : math.sin(math.pi * a.value.clamp(0, 1));

    return Scaffold(
      body: Semantics(
        button: true,
        label: 'NANA. Nunca Ausente, Nunca Abandonad@. Toca para continuar',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _irARol,
          child: DecoratedBox(
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
                  // Un golpe corto por ciclo, como un latido.
                  final golpe = math.pow(math.max(0, onda), 6).toDouble();

                  // La mascota empieza en el centro (donde la deja el splash
                  // nativo), rebota y sube a su lugar.
                  final centroFinal = alto * 0.3;
                  final centroY =
                      lerpDouble(alto / 2, centroFinal, v(_subir))!;
                  final flotar = quieto ? 0.0 : onda * 5 * v(_subir);
                  final escalaMascota = 1 + 0.1 * pico(_rebote);
                  final escalaCorazon = 1 +
                      0.35 * pico(_corazon) +
                      (quieto ? 0 : 0.25 * golpe * v(_pausa));
                  final tamanoHalo = 260 + (quieto ? 0.0 : onda * 10);

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
                        child: Transform.scale(
                          scale: escalaMascota,
                          child: MascotaNana(
                            tamano: _tamanoMascota,
                            ojosCerrados: pico(_parpadeo),
                            escalaCorazon: escalaCorazon,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: centroFinal + _tamanoMascota / 2 + 40,
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final (i, letra)
                                      in ['N', 'A', 'N', 'A'].indexed)
                                    _Letra(valor: v(_letras[i]), letra: letra),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _Aparecer(
                              valor: v(_lema),
                              child: const Text(
                                'Nunca Ausente, Nunca Abandonad@',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 112,
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
                        left: 0,
                        right: 0,
                        bottom: 44,
                        child: Column(
                          children: [
                            Opacity(
                              opacity: v(_lema),
                              child: SizedBox(
                                width: 120,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: quieto ? null : _c.value,
                                    minHeight: 5,
                                    backgroundColor: Colors.white,
                                    color: ColoresNana.lila,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Opacity(
                              opacity: v(_pista) * 0.8,
                              child: const Text(
                                'Toca para continuar',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B6485),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Cada letra de NANA cae un poco desde arriba con un rebote.
class _Letra extends StatelessWidget {
  final double valor;
  final String letra;
  const _Letra({required this.valor, required this.letra});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: valor.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, -28 * (1 - valor)),
        child: Transform.scale(
          scale: 0.7 + 0.3 * valor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              letra,
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: ColoresNana.morado,
                height: 1.1,
              ),
            ),
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

// Más discretos que el logo, para no robarle la atención.
class _Pilar extends StatelessWidget {
  final double valor;
  final IconData icono;
  final String texto;
  const _Pilar({required this.valor, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: valor.clamp(0, 1) * 0.85,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - valor)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ColoresNana.lila, width: 1.5),
              ),
              child: Icon(icono, color: ColoresNana.morado, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 16,
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
