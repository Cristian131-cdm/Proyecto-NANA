import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../core/tema.dart';

// Cómo se ve NANA: normal, contenta (completó su día), atenta (algo ya toca)
// o dormida (de noche). Lo decide estadoNana() en core/dia.dart. «Pensando»
// (ojos hacia arriba, boca recta) solo lo usa la plática mientras arma la
// respuesta.
enum EstadoNana { normal, contenta, atenta, dormida, pensando }

/// NANA dibujada con código, con el volumen y la luz del diseño B, y viva:
/// parpadea, le late el corazón, flota un poquito, mueve la boca cuando
/// habla y la rodea un aro cuando escucha. Con "Menos movimiento" se queda
/// quieta.
class MascotaNana extends StatefulWidget {
  final double tamano;
  final EstadoNana estado;

  // Si vienen, la animación la maneja quien la usa (el splash) y NANA no se
  // anima sola: 0 = ojos abiertos, 1 = cerrados; 1 = corazón normal.
  final double? ojosCerrados;
  final double? escalaCorazon;

  // Que mueva la boca cuando NANA habla y muestre que escucha.
  final bool conVoz;

  const MascotaNana({
    super.key,
    this.tamano = 84,
    this.estado = EstadoNana.normal,
    this.ojosCerrados,
    this.escalaCorazon,
    this.conVoz = true,
  });

  // Las pruebas la apagan (test/flutter_test_config.dart): una animación
  // que nunca termina no deja que pumpAndSettle acabe.
  static bool vive = true;

  @override
  State<MascotaNana> createState() => _MascotaNanaState();
}

class _MascotaNanaState extends State<MascotaNana>
    with TickerProviderStateMixin {
  // Un ciclo de 4.2 s: flota, late dos veces y parpadea al final.
  late final AnimationController _vida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  // La boca se abre y se cierra mientras suena la voz.
  late final AnimationController _boca = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
  );
  // El aro que crece mientras escucha.
  late final AnimationController _aro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _quieta = true;

  bool get _manejadaDesdeAfuera =>
      widget.ojosCerrados != null || widget.escalaCorazon != null;

  @override
  void initState() {
    super.initState();
    if (widget.conVoz) {
      Servicios.voz.hablando.addListener(_alCambiarVoz);
      Servicios.voz.escuchando.addListener(_alCambiarVoz);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quieta =
        !MascotaNana.vive ||
        _manejadaDesdeAfuera ||
        MediaQuery.disableAnimationsOf(context);
    if (_quieta) {
      _vida.stop();
      _vida.value = 0;
    } else if (!_vida.isAnimating) {
      _vida.repeat();
    }
    _alCambiarVoz();
  }

  void _alCambiarVoz() {
    if (!mounted) return;
    final habla = widget.conVoz && Servicios.voz.hablando.value;
    final escucha = widget.conVoz && Servicios.voz.escuchando.value;
    if (habla && !_quieta) {
      if (!_boca.isAnimating) _boca.repeat(reverse: true);
    } else {
      _boca.stop();
      // Quieta pero hablando: la boca se queda medio abierta.
      _boca.value = habla ? 0.5 : 0;
    }
    if (escucha && !_quieta) {
      if (!_aro.isAnimating) _aro.repeat();
    } else {
      _aro.stop();
      _aro.value = escucha ? 0.4 : 0;
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.conVoz) {
      Servicios.voz.hablando.removeListener(_alCambiarVoz);
      Servicios.voz.escuchando.removeListener(_alCambiarVoz);
    }
    _vida.dispose();
    _boca.dispose();
    _aro.dispose();
    super.dispose();
  }

  // Parpadeo rápido en el último 7% del ciclo.
  double _parpadeo(double v) =>
      v < 0.93 ? 0 : math.sin((v - 0.93) / 0.07 * math.pi);

  // Dos latidos seguidos al principio del ciclo ("pum-pum").
  double _latido(double v) {
    double pulso(double desde) {
      final x = (v - desde) / 0.1;
      return x < 0 || x > 1 ? 0 : math.sin(x * math.pi);
    }

    return 1 + 0.12 * pulso(0) + 0.08 * pulso(0.14);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamano;
    final escucha = widget.conVoz && Servicios.voz.escuchando.value;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_vida, _boca, _aro]),
        builder: (context, _) {
          final v = _vida.value;
          final flotar = _quieta ? 0.0 : math.sin(v * 2 * math.pi) * t * 0.018;
          return SizedBox(
            width: t,
            height: t,
            child: CustomPaint(
              painter: _NanaPainter(
                estado: escucha ? EstadoNana.atenta : widget.estado,
                ojosCerrados: widget.ojosCerrados ?? _parpadeo(v),
                corazon: widget.escalaCorazon ?? _latido(v),
                boca: _boca.value,
                aro: escucha ? _aro.value : null,
                flotar: flotar,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NanaPainter extends CustomPainter {
  final EstadoNana estado;
  final double ojosCerrados;
  final double corazon;
  final double boca; // 0 cerrada … 1 abierta (hablando)
  final double? aro; // 0 … 1 mientras escucha; null si no escucha
  final double flotar;

  _NanaPainter({
    required this.estado,
    required this.ojosCerrados,
    required this.corazon,
    required this.boca,
    required this.aro,
    required this.flotar,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = size.width;
    final caja = Offset.zero & size;

    // Aro de "te escucho": crece y se desvanece alrededor.
    if (aro case final a?) {
      final crece = t * 0.02 + t * 0.14 * a;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          caja.inflate(crece),
          Radius.circular(t * 0.28 + crece),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = t * 0.025
          ..color = ColoresNana.lila.withValues(alpha: 0.7 * (1 - a)),
      );
    }

    // Sombra suave en el piso: se achica cuando NANA sube.
    final sube = -flotar / (t * 0.018 + 0.0001); // -1 abajo … 1 arriba
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(t * 0.5, t * 0.98),
        width: t * (0.62 - 0.06 * sube.clamp(-1, 1)),
        height: t * 0.07,
      ),
      Paint()
        ..color = ColoresNana.mascotaBordeOscuro.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.03),
    );

    canvas.save();
    canvas.translate(0, flotar);

    // Borde lila con degradado y sombra.
    final borde = RRect.fromRectAndRadius(
      caja.deflate(t * 0.03),
      Radius.circular(t * 0.27),
    );
    canvas.drawRRect(
      borde.shift(Offset(0, t * 0.035)),
      Paint()
        ..color = ColoresNana.mascotaBordeOscuro.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.045),
    );
    canvas.drawRRect(
      borde,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColoresNana.mascotaBordeClaro,
            ColoresNana.mascotaBordeOscuro,
          ],
        ).createShader(borde.outerRect),
    );

    // Cascarón blanco perla con luz arriba a la izquierda.
    final cascaron = borde.deflate(t * 0.045);
    canvas.drawRRect(
      cascaron,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.45, -0.55),
          radius: 1.25,
          stops: [0, 0.55, 1],
          colors: [
            Colors.white,
            ColoresNana.mascotaCascaron,
            ColoresNana.mascotaCascaronSombra,
          ],
        ).createShader(cascaron.outerRect),
    );
    // Brillo.
    canvas.drawOval(
      Rect.fromLTWH(t * 0.16, t * 0.1, t * 0.32, t * 0.1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.025),
    );

    // Pantalla ciruela.
    final pantalla = RRect.fromRectAndRadius(
      Rect.fromLTWH(t * 0.17, t * 0.25, t * 0.66, t * 0.47),
      Radius.circular(t * 0.16),
    );
    canvas.drawRRect(
      pantalla,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColoresNana.mascotaPantalla,
            ColoresNana.mascotaPantallaOscura,
          ],
        ).createShader(pantalla.outerRect),
    );
    // Reflejo de vidrio en la parte de arriba de la pantalla.
    canvas.save();
    canvas.clipRRect(pantalla);
    canvas.drawOval(
      Rect.fromLTWH(t * 0.12, t * 0.13, t * 0.76, t * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
    canvas.restore();

    _cara(canvas, pantalla.outerRect);
    _corazon(canvas, Offset(t * 0.5, t * 0.85), t * 0.175 * corazon);

    canvas.restore();
  }

  void _corazon(Canvas canvas, Offset c, double ancho) {
    final w = ancho, h = ancho * 0.9;
    final p = Path()
      ..moveTo(c.dx, c.dy + h * 0.45)
      ..cubicTo(
        c.dx - w * 0.75,
        c.dy - h * 0.05,
        c.dx - w * 0.45,
        c.dy - h * 0.7,
        c.dx,
        c.dy - h * 0.25,
      )
      ..cubicTo(
        c.dx + w * 0.45,
        c.dy - h * 0.7,
        c.dx + w * 0.75,
        c.dy - h * 0.05,
        c.dx,
        c.dy + h * 0.45,
      )
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColoresNana.mascotaBordeClaro, ColoresNana.lila],
        ).createShader(p.getBounds()),
    );
  }

  void _cara(Canvas canvas, Rect r) {
    final w = r.width, h = r.height;
    Offset en(double x, double y) => Offset(r.left + w * x, r.top + h * y);

    final grosor = w * 0.06;
    final linea = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    final blanco = Paint()..color = Colors.white;
    // Un brillo suave alrededor de los ojos y la boca, como de pantalla.
    final brillo = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04);

    final radio = w * 0.075;
    for (final x in [0.32, 0.68]) {
      final c = en(x, 0.4);
      switch (estado) {
        case EstadoNana.contenta:
          // Ojos felices: arquitos hacia arriba.
          final arco = Rect.fromCenter(
            center: c.translate(0, radio * 0.7),
            width: 2.6 * radio,
            height: 2.6 * radio,
          );
          canvas.drawArc(arco, 3.5, 2.4, false, linea);
        case EstadoNana.dormida:
          // Párpados cerrados, curvitas hacia abajo.
          final arco = Rect.fromCenter(
            center: c.translate(0, -radio * 0.6),
            width: 2.4 * radio,
            height: 2 * radio,
          );
          canvas.drawArc(arco, 0.5, 2.1, false, linea);
        case EstadoNana.pensando:
          // Ojos chicos mirando hacia arriba, a un lado.
          final ojo = Rect.fromCenter(
            center: c.translate(radio * 0.7, -radio * 0.8),
            width: 1.5 * radio,
            height: (1.5 * radio * (1 - ojosCerrados)).clamp(
              radio * 0.3,
              3 * radio,
            ),
          );
          canvas.drawOval(ojo.inflate(radio * 0.3), brillo);
          canvas.drawOval(ojo, blanco);
        case EstadoNana.atenta || EstadoNana.normal:
          final grande = estado == EstadoNana.atenta ? 1.15 : 1.0;
          // Al parpadear el ojo se aplana hasta quedar como una línea.
          final alto = (2 * radio * grande * (1 - ojosCerrados)).clamp(
            radio * 0.3,
            3 * radio,
          );
          final ojo = Rect.fromCenter(
            center: c,
            width: 2 * radio * grande,
            height: alto,
          );
          canvas.drawOval(ojo.inflate(radio * 0.3), brillo);
          canvas.drawOval(ojo, blanco);
      }
    }

    // Hablando: boca abierta que se mueve (salvo dormida).
    if (boca > 0.02 && estado != EstadoNana.dormida) {
      final abre = h * (0.05 + 0.16 * boca);
      final b = Rect.fromCenter(
        center: en(0.5, 0.72),
        width: w * (0.2 + 0.04 * boca),
        height: abre,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, Radius.circular(abre / 2)),
        blanco,
      );
      return;
    }

    switch (estado) {
      case EstadoNana.contenta:
        canvas.drawArc(
          Rect.fromCenter(
            center: en(0.5, 0.6),
            width: w * 0.36,
            height: h * 0.36,
          ),
          0.2,
          2.74,
          false,
          linea,
        );
      case EstadoNana.atenta:
        // Boquita en "o": está pendiente.
        canvas.drawCircle(en(0.5, 0.74), w * 0.04, linea);
      case EstadoNana.pensando:
        // Boca recta, un poco de lado.
        canvas.drawLine(en(0.44, 0.72), en(0.6, 0.7), linea);
      case EstadoNana.dormida:
        canvas.drawArc(
          Rect.fromCenter(
            center: en(0.5, 0.66),
            width: w * 0.16,
            height: h * 0.14,
          ),
          0.4,
          2.3,
          false,
          linea,
        );
      case EstadoNana.normal:
        canvas.drawArc(
          Rect.fromCenter(
            center: en(0.5, 0.6),
            width: w * 0.3,
            height: h * 0.3,
          ),
          0.25,
          2.64,
          false,
          linea,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _NanaPainter old) =>
      old.estado != estado ||
      old.ojosCerrados != ojosCerrados ||
      old.corazon != corazon ||
      old.boca != boca ||
      old.aro != aro ||
      old.flotar != flotar;
}
