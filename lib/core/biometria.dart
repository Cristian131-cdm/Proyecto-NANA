import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// Huella, Face ID o, si no hay, el PIN o patrón del celular. Solo desbloquea
// NANA en este aparato; no es una forma de registrarse.
abstract class Biometria {
  Future<bool> disponible();
  Future<bool> autenticar(String motivo);
}

class BiometriaLocal implements Biometria {
  final _auth = LocalAuthentication();

  @override
  Future<bool> disponible() async {
    if (kIsWeb) return false;
    try {
      // Si el sistema no contesta, mejor seguir sin huella que trabarse.
      return await _auth.isDeviceSupported().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> autenticar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

const minutosParaBloquear = 30;

// [enSegundoPlanDesde] es null cuando la app arranca en frío.
bool hayQuePedirHuella({
  required bool activada,
  required DateTime? enSegundoPlanDesde,
  required DateTime ahora,
  required bool vieneDeAlarma,
}) {
  if (!activada || vieneDeAlarma) return false;
  if (enSegundoPlanDesde == null) return true;
  return ahora.difference(enSegundoPlanDesde) >=
      const Duration(minutes: minutosParaBloquear);
}
