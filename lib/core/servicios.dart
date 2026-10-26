import '../data/repositorio.dart';
import '../data/repositorio_memoria.dart';
import 'biometria.dart';

// Lo que la app usa por dentro. main() pone las versiones reales y las
// pruebas ponen versiones de mentira, igual que con Ajustes.
class Servicios {
  static RepositorioNana repo = RepositorioMemoria();
  static Biometria biometria = BiometriaLocal();

  // La hora "de ahora"; las pruebas la fijan para que no dependan del reloj.
  static DateTime Function() reloj = DateTime.now;
}
