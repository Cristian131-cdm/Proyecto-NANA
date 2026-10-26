import '../data/repositorio.dart';
import '../data/repositorio_memoria.dart';

// Lo que la app usa por dentro. main() pone las versiones reales y las
// pruebas ponen versiones de mentira, igual que con Ajustes.
class Servicios {
  static RepositorioNana repo = RepositorioMemoria();

  // La hora "de ahora"; las pruebas la fijan para que no dependan del reloj.
  static DateTime Function() reloj = DateTime.now;
}
