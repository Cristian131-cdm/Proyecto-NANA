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

  // true: la ilustración del diseño B (assets/mascota/), con volumen y luz.
  // false: la misma NANA dibujada con código, para cuando se anima (parpadeo,
  // corazón que late, boca que habla). Se usa sola si se pide animación.
  final bool ilustrada;

  const MascotaNana({
    super.key,
    this.tamano = 84,
    this.ojosCerrados = 0,
    this.escalaCorazon = 1,
    this.estado = EstadoNana.normal,
    this.ilustrada = true,
  });

  // La ilustración deja ~12% de aire en cada lado; se agranda para que mida
  // lo mismo que la dibujada.
  static const _aireIlustracion = 0.76;

  @override
  Widget build(BuildContext context) {
    final animada = ojosCerrados != 0 || escalaCorazon != 1;
    if (ilustrada && !animada) {
      return SizedBox(
        width: tamano,
        height: tamano,
        child: OverflowBox(
          maxWidth: tamano / _aireIlustracion,
          maxHeight: tamano / _aireIlustracion,
          child: Image.asset(
            'assets/mascota/nana_${estado.name}.png',
            width: tamano / _aireIlustracion,
            height: tamano / _aireIlustracion,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            gaplessPlayback: true,
            // Si la imagen no carga, la dibujada.
            errorBuilder: (_, _, _) => _dibujada(),
          ),
        ),
      );
    }
    return _dibujada();
  }

  Widget _dibujada() {
    final t = tamano;
    return SizedBox(
      width: t,
      height: t,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Borde lila con degradado.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t * 0.285),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColoresNana.mascotaBordeClaro,
                  ColoresNana.mascotaBordeOscuro,
                ],
              ),
            ),
          ),
          // Cascarón blanco perla.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(t * 0.04),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t * 0.254),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0, 0.6, 1],
                    colors: [
                      Colors.white,
                      ColoresNana.mascotaCascaron,
                      ColoresNana.mascotaCascaronSombra,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Pantalla con la cara.
          Positioned(
            top: t * 0.25,
            child: Container(
              width: t * 0.66,
              height: t * 0.49,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t * 0.16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColoresNana.mascotaPantalla,
                    ColoresNana.mascotaPantallaOscura,
                  ],
                ),
              ),
              child: CustomPaint(painter: _CaraPainter(ojosCerrados, estado)),
            ),
          ),
          Positioned(
            bottom: t * 0.035,
            child: Transform.scale(
              scale: escalaCorazon,
              child: Icon(
                Icons.favorite,
                color: ColoresNana.lila,
                size: t * 0.18,
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
