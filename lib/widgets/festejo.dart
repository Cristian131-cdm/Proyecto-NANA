import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/tema.dart';

// Festejo corto al marcar algo como hecho ("Ya la tomé"): una palomita que se
// dibuja, una vibración y un texto. Se cierra solo. Con "reducir animaciones"
// la palomita sale completa desde el inicio.
Future<void> mostrarFestejo(BuildContext context, String texto) async {
  HapticFeedback.mediumImpact();
  final quieto = MediaQuery.disableAnimationsOf(context);
  final navegador = Navigator.of(context);
  var abierto = true;
  final cerrar = Timer(Duration(milliseconds: quieto ? 1000 : 1400), () {
    if (abierto) navegador.pop();
  });
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black26,
    transitionDuration: Duration(milliseconds: quieto ? 0 : 180),
    pageBuilder: (context, _, _) => Center(
      child: _Festejo(texto: texto, quieto: quieto),
    ),
  );
  abierto = false;
  cerrar.cancel();
}

class _Festejo extends StatelessWidget {
  final String texto;
  final bool quieto;
  const _Festejo({required this.texto, required this.quieto});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: texto,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: quieto ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: const Size(110, 110),
                  painter: _Palomita(t),
                ),
              ),
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: ColoresNana.ok,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Círculo que se llena y luego la palomita, según t de 0 a 1.
class _Palomita extends CustomPainter {
  final double t;
  _Palomita(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final aro = (t / 0.5).clamp(0.0, 1.0);
    final trazo = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

    canvas.drawCircle(c, r, Paint()..color = ColoresNana.okClaro);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * aro,
      false,
      Paint()
        ..color = ColoresNana.ok
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    if (trazo == 0) return;
    final camino = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.37);
    final metrica = camino.computeMetrics().first;
    canvas.drawPath(
      metrica.extractPath(0, metrica.length * trazo),
      Paint()
        ..color = ColoresNana.ok
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Palomita vieja) => vieja.t != t;
}
