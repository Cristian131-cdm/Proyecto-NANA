import 'package:flutter/material.dart';

import '../core/tema.dart';

// Cómo se ve NANA: normal, contenta (completó su día), atenta (algo ya toca)
// o dormida (de noche). Lo decide estadoNana() en core/dia.dart.
enum EstadoNana { normal, contenta, atenta, dormida }

class MascotaNana extends StatelessWidget {
  final double tamano;
  final EstadoNana estado;

  // Para animarla: 0 = ojos abiertos, 1 = cerrados; y qué tan grande late
  // el corazón (1 = normal).
  final double ojosCerrados;
  final double escalaCorazon;

  const MascotaNana({
    super.key,
    this.tamano = 84,
    this.ojosCerrados = 0,
    this.escalaCorazon = 1,
    this.estado = EstadoNana.normal,
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
            child: CustomPaint(painter: _CaraPainter(ojosCerrados, estado)),
          ),
          Positioned(
            bottom: tamano * 0.02,
            child: Transform.scale(
              scale: escalaCorazon,
              child: Icon(
                Icons.favorite,
                color: ColoresNana.lila,
                size: tamano * 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaraPainter extends CustomPainter {
  final double ojosCerrados;
  final EstadoNana estado;
  _CaraPainter(this.ojosCerrados, this.estado);

  @override
  void paint(Canvas canvas, Size size) {
    final blanco = Paint()..color = Colors.white;
    final linea = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    final r = size.width * 0.06;

    for (final x in [0.33, 0.67]) {
      final centro = Offset(size.width * x, size.height * 0.38);
      switch (estado) {
        // Ojos felices: arquitos hacia arriba.
        case EstadoNana.contenta:
          canvas.drawArc(
            Rect.fromCenter(
              center: centro.translate(0, r * 0.6),
              width: 2.4 * r,
              height: 2.4 * r,
            ),
            3.5,
            2.4,
            false,
            linea,
          );
        // Dormida: rayitas.
        case EstadoNana.dormida:
          canvas.drawLine(
            centro.translate(-r, 0),
            centro.translate(r, 0),
            linea,
          );
        // Atenta: ojos un poco más grandes.
        case EstadoNana.atenta:
          canvas.drawOval(
            Rect.fromCenter(
              center: centro,
              width: 2.4 * r,
              height: 2.8 * r * (1 - ojosCerrados * 0.85),
            ),
            blanco,
          );
        case EstadoNana.normal:
          // Al parpadear el ojo se aplana en vertical hasta quedar como una línea.
          final alto = (2 * r * (1 - ojosCerrados)).clamp(r * 0.25, 2 * r);
          canvas.drawOval(
            Rect.fromCenter(center: centro, width: 2 * r, height: alto),
            blanco,
          );
      }
    }

    final boca = Offset(size.width * 0.5, size.height * 0.55);
    switch (estado) {
      case EstadoNana.contenta:
        canvas.drawArc(
          Rect.fromCenter(
            center: boca,
            width: size.width * 0.38,
            height: size.height * 0.4,
          ),
          0.15,
          2.85,
          false,
          linea,
        );
      case EstadoNana.atenta:
        // Boquita en "o": está pendiente.
        canvas.drawCircle(
          boca.translate(0, size.height * 0.12),
          size.width * 0.045,
          linea,
        );
      case EstadoNana.dormida:
        canvas.drawArc(
          Rect.fromCenter(
            center: boca.translate(0, size.height * 0.05),
            width: size.width * 0.18,
            height: size.height * 0.16,
          ),
          0.4,
          2.3,
          false,
          linea,
        );
      case EstadoNana.normal:
        canvas.drawArc(
          Rect.fromCenter(
            center: boca,
            width: size.width * 0.3,
            height: size.height * 0.3,
          ),
          0.2,
          2.7,
          false,
          linea,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CaraPainter old) =>
      old.ojosCerrados != ojosCerrados || old.estado != estado;
}
