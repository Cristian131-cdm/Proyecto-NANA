import 'package:flutter/material.dart';
import '../core/tema.dart';

class MascotaNana extends StatelessWidget {
  final double tamano;

  // Para animarla: 0 = ojos abiertos, 1 = cerrados; y qué tan grande late
  // el corazón (1 = normal).
  final double ojosCerrados;
  final double escalaCorazon;

  const MascotaNana({
    super.key,
    this.tamano = 84,
    this.ojosCerrados = 0,
    this.escalaCorazon = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColoresNana.moradoClaro,
              borderRadius: BorderRadius.circular(tamano * 0.38),
              border: Border.all(color: ColoresNana.lila, width: tamano * 0.04),
            ),
          ),
          Container(
            width: tamano * 0.7,
            height: tamano * 0.5,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1426),
              borderRadius: BorderRadius.circular(tamano * 0.2),
            ),
            child: CustomPaint(painter: _CaraPainter(ojosCerrados)),
          ),
          Positioned(
            bottom: tamano * 0.02,
            child: Transform.scale(
              scale: escalaCorazon,
              child: Icon(Icons.favorite,
                  color: ColoresNana.lila, size: tamano * 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaraPainter extends CustomPainter {
  final double ojosCerrados;
  _CaraPainter(this.ojosCerrados);

  @override
  void paint(Canvas canvas, Size size) {
    final ojo = Paint()..color = Colors.white;
    final r = size.width * 0.06;
    // Al parpadear el ojo se aplana en vertical hasta quedar como una línea.
    final alto = (2 * r * (1 - ojosCerrados)).clamp(r * 0.25, 2 * r);
    for (final x in [0.33, 0.67]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.38),
          width: 2 * r,
          height: alto,
        ),
        ojo,
      );
    }

    final sonrisa = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.55),
      width: size.width * 0.3,
      height: size.height * 0.3,
    );
    canvas.drawArc(rect, 0.2, 2.7, false, sonrisa);
  }

  @override
  bool shouldRepaint(covariant _CaraPainter old) =>
      old.ojosCerrados != ojosCerrados;
}
