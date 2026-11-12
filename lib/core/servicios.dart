import '../data/repositorio.dart';
import '../data/repositorio_memoria.dart';
import 'alarmas.dart';
import 'avisos.dart';
import 'biometria.dart';
import 'lector_expediente.dart';
import 'senas/catalogo.dart';
import 'senas/ojo.dart';
import 'voz.dart';

// Lo que la app usa por dentro. main() pone las versiones reales y las
// pruebas ponen versiones de mentira, igual que con Ajustes.
class Servicios {
  static RepositorioNana repo = RepositorioMemoria();
  static Biometria biometria = BiometriaLocal();
  static Alarmas alarmas = AlarmasLocales();
  static Avisos avisos = const AvisosNulos();
  static LectorExpediente lector = const LectorSimulado();
  static Voz voz = VozNula();

  // Señas: cómo se prende la cámara y dónde están los ejemplos guardados.
  static OjoSenas Function() crearOjo = OjoSinCamara.new;
  static AlmacenSenas senas = AlmacenSenas();

  // La hora "de ahora"; las pruebas la fijan para que no dependan del reloj.
  static DateTime Function() reloj = DateTime.now;
}
