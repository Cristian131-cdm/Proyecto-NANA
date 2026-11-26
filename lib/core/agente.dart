import '../models/medicina_leida.dart';
import '../models/actividad.dart';

// El agente de NANA (carpeta agente/ del repo, en Python) corre en la laptop
// durante las pruebas y la demo. La app le pregunta solo lo que sus reglas
// fijas no resuelven (ver panel_adulto.dart); si no contesta a tiempo, NANA
// sigue con sus respuestas de siempre. Nada crítico depende de él: pedir
// ayuda, la pregunta médica y llamar a la familia se resuelven antes, aquí.

/// Lo que el agente propone anotar. Nunca se anota sin que la persona diga
/// que sí.
class PropuestaAgente {
  final String tipo; // 'registro' | 'animo' | 'aviso_familia'
  final String id; // el id que le mandamos en el día
  final String pregunta;

  const PropuestaAgente({
    required this.tipo,
    required this.id,
    required this.pregunta,
  });
}

class RespuestaAgente {
  final String etiqueta;
  final String texto;
  // 'abrir_ayuda' | 'abrir_familia' | 'ofrecer_familia' | 'abrir_mi_dia' | ''
  final String accion;
  final PropuestaAgente? propuesta;
  final String proveedor;

  const RespuestaAgente({
    required this.etiqueta,
    required this.texto,
    this.accion = '',
    this.propuesta,
    this.proveedor = '',
  });

  /// Lo que regresa `Resultado.a_json()` en Python. null si no sirve.
  static RespuestaAgente? deJson(Object? j) {
    if (j is! Map) return null;
    final texto = j['texto'];
    if (texto is! String || texto.trim().isEmpty) return null;
    final p = j['propuesta'];
    return RespuestaAgente(
      etiqueta: '${j['etiqueta'] ?? ''}',
      texto: texto.trim(),
      accion: '${j['accion'] ?? ''}',
      proveedor: '${j['proveedor'] ?? ''}',
      propuesta: p is Map && p['pregunta'] is String
          ? PropuestaAgente(
              tipo: '${p['tipo'] ?? ''}',
              id: '${p['id'] ?? ''}',
              pregunta: p['pregunta'] as String,
            )
          : null,
    );
  }
}

/// Lo que contesta el botón «Probar»: qué modelo hay y si la clave sirve.
class SaludAgente {
  final String modelo;
  final bool claveOk;
  const SaludAgente({required this.modelo, this.claveOk = true});
}

abstract class Agente {
  /// Hay un servidor configurado en este celular.
  bool get disponible;

  /// null si no hay servidor, tarda más del límite o contesta algo raro.
  Future<RespuestaAgente?> preguntar({
    required String texto,
    required String nombre,
    required List<Map<String, Object?>> dia,
    required List<Map<String, String>> historial,
  });

  /// «Pregúntale a NANA» del encargado: solo lectura, con el resumen que
  /// armó la app (core/resumen_encargado.dart). null igual que [preguntar].
  Future<RespuestaAgente?> preguntarEncargado({
    required String pregunta,
    required String nombre,
    required Map<String, Object?> datos,
    required List<Map<String, String>> historial,
  });

  /// Para el botón «Probar»: qué modelo contesta, o null si no lo encuentra.
  Future<SaludAgente?> salud();

  /// Lee el texto de una receta (OCR del celular) y propone las medicinas.
  /// null si no hay agente o no contestó; lista vacía si no encontró nada.
  Future<List<MedicinaLeida>?> leerReceta(String texto);
}

List<MedicinaLeida>? medicinasDeJson(Map<String, dynamic>? j) {
  final lista = j?['medicinas'];
  if (lista is! List) return null;
  return [for (final m in lista) ?MedicinaLeida.deJson(m)];
}

/// En pruebas y en web: no hay agente y la app contesta como siempre.
class AgenteNulo implements Agente {
  const AgenteNulo();

  @override
  bool get disponible => false;

  @override
  Future<RespuestaAgente?> preguntar({
    required String texto,
    required String nombre,
    required List<Map<String, Object?>> dia,
    required List<Map<String, String>> historial,
  }) async => null;

  @override
  Future<RespuestaAgente?> preguntarEncargado({
    required String pregunta,
    required String nombre,
    required Map<String, Object?> datos,
    required List<Map<String, String>> historial,
  }) async => null;

  @override
  Future<SaludAgente?> salud() async => null;

  @override
  Future<List<MedicinaLeida>?> leerReceta(String texto) async => null;
}

/// Para las pruebas: contesta lo que diga [contestar] y recuerda qué le
/// preguntaron.
class AgenteFalso implements Agente {
  final RespuestaAgente? Function(String texto) contestar;
  final List<({String texto, List<Map<String, Object?>> dia, int historial})>
  pedidos = [];

  AgenteFalso(this.contestar);

  @override
  bool get disponible => true;

  @override
  Future<RespuestaAgente?> preguntar({
    required String texto,
    required String nombre,
    required List<Map<String, Object?>> dia,
    required List<Map<String, String>> historial,
  }) async {
    pedidos.add((texto: texto, dia: dia, historial: historial.length));
    return contestar(texto);
  }

  /// Lo que se le preguntó como encargado (pregunta y resumen).
  final List<({String pregunta, Map<String, Object?> datos})>
  preguntasEncargado = [];

  @override
  Future<RespuestaAgente?> preguntarEncargado({
    required String pregunta,
    required String nombre,
    required Map<String, Object?> datos,
    required List<Map<String, String>> historial,
  }) async {
    preguntasEncargado.add((pregunta: pregunta, datos: datos));
    return contestar(pregunta);
  }

  @override
  Future<SaludAgente?> salud() async => const SaludAgente(modelo: 'falso');

  /// Lo que «lee» de una receta (pruebas).
  List<MedicinaLeida>? receta;
  final List<String> recetasLeidas = [];

  @override
  Future<List<MedicinaLeida>?> leerReceta(String texto) async {
    recetasLeidas.add(texto);
    return receta;
  }
}

/// "192.168.100.3" → "http://192.168.100.3:8787". Respeta el puerto o el
/// http:// si los escribieron. null si está vacío.
String? urlDelServidor(String escrito) {
  var s = escrito.trim();
  if (s.isEmpty) return null;
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.hasPort) return '${uri.scheme}://${uri.host}:${uri.port}';
  // https = el túnel de Cloudflare (`https://….trycloudflare.com`): usa el
  // puerto normal. Solo la laptop en el Wi-Fi va directo al 8787.
  return uri.scheme == 'https'
      ? 'https://${uri.host}'
      : '${uri.scheme}://${uri.host}:8787';
}

/// El id con que el agente conoce cada pendiente: el de la medicina, o su
/// lugar en la lista para lo demás (comida, caminar…).
String idParaAgente(Actividad a, int i) => a.idMedicamento ?? 'a$i';

/// El día como lo espera `Peticion.de_json` en Python: solo título y hora,
/// nunca nada más del expediente.
List<Map<String, Object?>> diaParaAgente(List<Actividad> dia) => [
  for (final (i, a) in dia.indexed)
    if (a.tipo != TipoActividad.animo && a.tipo != TipoActividad.mensaje)
      {
        'id': idParaAgente(a, i),
        'tipo': switch (a.tipo) {
          TipoActividad.medicina => 'medicina',
          TipoActividad.comida => 'comida',
          TipoActividad.ejercicio => 'ejercicio',
          _ => 'otro',
        },
        'titulo': a.titulo,
        'hora': a.hora,
        'hecho': a.estado == EstadoActividad.hecha,
      },
];

/// La actividad que el agente propone anotar, o null si no la encuentra.
Actividad? actividadPropuesta(List<Actividad> dia, String id) {
  for (final (i, a) in dia.indexed) {
    if (idParaAgente(a, i) == id) return a;
  }
  return null;
}
