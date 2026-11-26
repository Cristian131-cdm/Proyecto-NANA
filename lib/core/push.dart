import 'package:flutter/foundation.dart';

// Push con la app cerrada (Cloudflare Worker `avisos_worker/` + FCM).
// El Worker manda: «necesita ayuda», «dijo…», medicina olvidada y «sin
// noticias» a la familia. La app solo guarda el token de este celular y le
// avisa al Worker en cuanto se pide ayuda, para no esperar al minuto del cron.
abstract class Push {
  // Pide permiso, guarda el token de este celular y escucha los que llegan
  // con la app abierta.
  Future<void> registrar();
  // «Revisa ya a esta persona»: se llama justo después de crear una alerta.
  Future<void> avisarAhora(String folio);
}

// Dirección del Worker (desplegado el 2026-11-25 en la cuenta del proyecto).
// Se puede cambiar con --dart-define=NANA_AVISOS=https://...
// Si no contesta, el cron igual manda el aviso en ≤ 5 min.
const urlAvisos = String.fromEnvironment(
  'NANA_AVISOS',
  defaultValue: 'https://nana-avisos.nana-agente.workers.dev',
);

class PushNulo implements Push {
  final List<String> avisados = [];
  @override
  Future<void> registrar() async {}
  @override
  Future<void> avisarAhora(String folio) async => avisados.add(folio);
}

// Lo que se hace con un push que llega con NANA abierta. Las alertas ya las
// muestra y dice VigilanteAlertas; lo demás (medicina olvidada, sin noticias)
// se muestra y se dice aquí. Regresa null si no hay que hacer nada.
({String titulo, String cuerpo})? pushEnPantalla(
  Map<String, dynamic> datos,
  String? titulo,
  String? cuerpo,
) {
  if (datos['tipo'] == 'alerta' || titulo == null) return null;
  return (titulo: titulo, cuerpo: cuerpo ?? '');
}

void registrarFalla(String que, Object e) =>
    debugPrint('NANA push: no pude $que ($e)');
