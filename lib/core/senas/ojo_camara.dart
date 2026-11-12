import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'clasificador.dart';
import 'ojo.dart';

// La cámara de verdad (por ahora solo Android: usa MediaPipe Hand
// Landmarker). Todo pasa en el celular: cada cuadro se convierte en 21 puntos
// de la mano y el cuadro se descarta. No se graba ni se manda nada.
OjoSenas crearOjoCamara() => defaultTargetPlatform == TargetPlatform.android
    ? OjoCamara()
    : OjoSinCamara();

class OjoCamara implements OjoSenas {
  CameraController? _camara;
  HandLandmarkerPlugin? _detector;
  StreamSubscription<List<Hand>>? _sub;
  final _manos = StreamController<ManoVista?>.broadcast();
  bool _cerrado = false;
  int _sensor = 0;
  DateTime _ultimo = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<ManoVista?> get manos => _manos.stream;

  @override
  Future<String?> abrir() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) return 'Este celular no tiene cámara';
      // La de enfrente, para que la persona se vea mientras hace la seña.
      final elegida = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      _sensor = elegida.sensorOrientation;
      final camara = _camara = CameraController(
        elegida,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await camara.initialize();
      final detector = _detector = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.6,
      );
      _sub = detector.landmarkStream.listen(_alDetectar);
      if (_cerrado) {
        await cerrar();
        return null;
      }
      await camara.startImageStream(_alLlegarCuadro);
      return null;
    } on CameraException catch (e) {
      debugPrint('NANA cámara: ${e.code} ${e.description}');
      await cerrar();
      return e.code.toLowerCase().contains('denied')
          ? 'No diste permiso de usar la cámara'
          : 'No pude prender la cámara';
    } catch (e) {
      debugPrint('NANA cámara: $e');
      await cerrar();
      return 'No pude prender la cámara';
    }
  }

  void _alLlegarCuadro(CameraImage cuadro) {
    if (_cerrado) return;
    // Unas 10 veces por segundo bastan y el celular no se calienta.
    final ahora = DateTime.now();
    if (ahora.difference(_ultimo).inMilliseconds < 100) return;
    _ultimo = ahora;
    try {
      _detector?.processFrame(cuadro, _sensor);
    } catch (e) {
      debugPrint('NANA señas: $e');
    }
  }

  void _alDetectar(List<Hand> vistas) {
    if (_cerrado || _manos.isClosed) return;
    final con21 = vistas.where((h) => h.landmarks.length == puntosPorMano);
    if (con21.isEmpty) {
      _manos.add(null);
      return;
    }
    final mano = normalizarMano([
      for (final p in con21.first.landmarks) (x: p.x, y: p.y, z: p.z),
    ]);
    final pulgar = pulgarDe(mano);
    _manos.add(
      ManoVista(
        mano,
        pulgarArriba: pulgar == Pulgar.arriba,
        pulgarAbajo: pulgar == Pulgar.abajo,
      ),
    );
  }

  @override
  Widget vista() {
    final c = _camara;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return CameraPreview(c);
  }

  @override
  Future<void> cerrar() async {
    _cerrado = true;
    final camara = _camara, detector = _detector;
    _camara = null;
    _detector = null;
    await _sub?.cancel();
    _sub = null;
    try {
      if (camara != null && camara.value.isStreamingImages) {
        await camara.stopImageStream();
      }
    } catch (_) {}
    try {
      await camara?.dispose();
    } catch (_) {}
    try {
      detector?.dispose();
    } catch (_) {}
    if (!_manos.isClosed) await _manos.close();
  }
}
