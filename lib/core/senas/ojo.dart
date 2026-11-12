import 'package:flutter/widgets.dart';

// El "ojo" de NANA para las señas: prende la cámara y entrega la mano que
// ve, ya convertida en números. La versión real (ojo_camara.dart) usa la
// cámara del celular; las pruebas usan una de mentira.
class ManoVista {
  final List<double> mano; // 21 puntos normalizados (clasificador.dart)
  // Pulgar arriba / abajo, que el detector ya reconoce solo: sirven de
  // "sí" y "no" aunque nadie haya grabado esas señas.
  final bool pulgarArriba;
  final bool pulgarAbajo;

  const ManoVista(
    this.mano, {
    this.pulgarArriba = false,
    this.pulgarAbajo = false,
  });
}

abstract class OjoSenas {
  /// Prende la cámara. Regresa null si todo bien, o el motivo para
  /// mostrarlo ("No diste permiso de usar la cámara").
  Future<String?> abrir();

  /// Lo que ve en cada cuadro: una mano, o null si no hay mano.
  Stream<ManoVista?> get manos;

  /// Lo que ve la cámara, para que la persona se acomode.
  Widget vista();

  /// Apaga la cámara. No queda nada grabado.
  Future<void> cerrar();
}

// Donde no hay cámara (pruebas, o un aparato sin ella).
class OjoSinCamara implements OjoSenas {
  @override
  Future<String?> abrir() async => 'Este aparato no tiene cámara para señas';
  @override
  Stream<ManoVista?> get manos => const Stream.empty();
  @override
  Widget vista() => const SizedBox.shrink();
  @override
  Future<void> cerrar() async {}
}
