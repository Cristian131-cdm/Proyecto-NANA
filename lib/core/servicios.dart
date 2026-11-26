import '../data/repositorio.dart';
import '../data/repositorio_memoria.dart';
import 'agente.dart';
import 'alarmas.dart';
import 'avisos.dart';
import 'biometria.dart';
import 'despertador.dart';
import 'fotos_locales.dart';
import 'lector_expediente.dart';
import 'ocr_receta.dart';
import 'push.dart';
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
  // Push con la app cerrada (Worker de Cloudflare). main() pone el real.
  static Push push = PushNulo();
  // Foto de la receta + OCR dentro del celular. main() pone el real.
  static OcrReceta ocr = const OcrNulo();
  static LectorExpediente lector = const LectorSimulado();
  static Voz voz = VozNula();
  // «Oye NANA». main() pone el de verdad; en pruebas no escucha nada.
  static Despertador despertador = DespertadorNulo();
  // El agente de la laptop (Fase 4). Sin servidor configurado no hace nada.
  static Agente agente = const AgenteNulo();
  // Fotos de recetas: solo en este celular, nunca en la nube.
  static FotosLocales fotos = const SinFotos();

  // Señas: cómo se prende la cámara y dónde están los ejemplos guardados.
  static OjoSenas Function() crearOjo = OjoSinCamara.new;
  static AlmacenSenas senas = AlmacenSenas();

  // La hora "de ahora"; las pruebas la fijan para que no dependan del reloj.
  static DateTime Function() reloj = DateTime.now;
}
