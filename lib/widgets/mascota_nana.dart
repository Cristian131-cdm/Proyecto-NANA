import 'package:flutter/material.dart';
import '../core/tema.dart';

class MascotaNana extends StatelessWidget {
  final double tamano;
  const MascotaNana({super.key, this.tamano = 84});

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
            child: CustomPaint(painter: _CaraPainter()),
          ),
          Positioned(
            bottom: tamano * 0.02,
            child: Icon(Icons.favorite,
                color: ColoresNana.lila, size: tamano * 0.2),
          ),
        ],
      ),
    );
  }
}

class _CaraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ojo = Paint()..color = Colors.white;
    final r = size.width * 0.06;
    canvas.drawCircle(Offset(size.width * 0.33, size.height * 0.38), r, ojo);
    canvas.drawCircle(Offset(size.width * 0.67, size.height * 0.38), r, ojo);

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}