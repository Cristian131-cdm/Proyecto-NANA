import '../data/repositorio.dart';
import '../data/repositorio_memoria.dart';
import 'alarmas.dart';
import 'biometria.dart';

// Lo que la app usa por dentro. main() pone las versiones reales y las
// pruebas ponen versiones de mentira, igual que con Ajustes.
class Servicios {
  static RepositorioNana repo = RepositorioMemoria();
  static Biometria biometria = BiometriaLocal();
  static Alarmas alarmas = AlarmasLocales();

  // La hora "de ahora"; las pruebas la fijan para que no dependan del reloj.
  static DateTime Function() reloj = DateTime.now;
}
