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
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _escala;
  late final Animation<double> _opacidadMascota;
  late final Animation<double> _opacidadTexto;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _escala = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );
    _opacidadMascota = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );
    _opacidadTexto = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );

    _c.forward().then((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const SeleccionRol(),
          transitionsBuilder: (_, animacion, __, child) =>
              FadeTransition(opacity: animacion, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresNana.fondo,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _opacidadMascota.value,
                      child: Transform.scale(
                        scale: _escala.value,
                        child: const MascotaNana(tamano: 160),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: _opacidadTexto.value,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - _opacidadTexto.value)),
                        child: const Column(
                          children: [
                            Text(
                              'NANA',
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.bold,
                                color: ColoresNana.morado,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Nunca Ausente, Nunca Abandonad@',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: Opacity(
                  opacity: _opacidadTexto.value,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _c.value,
                            minHeight: 8,
                            backgroundColor: ColoresNana.moradoClaro,
                            color: ColoresNana.lila,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cuido · Acompaño · Protejo',
                        style: TextStyle(
                          fontSize: 15,
                          color: ColoresNana.morado,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}