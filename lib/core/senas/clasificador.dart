import 'dart:convert';
import 'dart:math' as math;

// Reconocer señas sin nube ni entrenamiento pesado: la cámara da 21 puntos
// de la mano (muñeca, nudillos y puntas de los dedos); aquí se comparan con
// ejemplos guardados y gana la seña que más se parece (vecinos más cercanos).
// "Enseñarle" una seña nueva es guardar más ejemplos.
//
// Sirve para señas que son una postura de la mano. Las que llevan movimiento
// quedan para después.

const puntosPorMano = 21;

/// Un punto de la mano tal como lo da la cámara.
typedef Punto = ({double x, double y, double z});

/// Deja la mano comparable sin importar dónde está en la imagen ni qué tan
/// cerca: la muñeca queda en el origen y el tamaño se iguala. La mano
/// izquierda se voltea como espejo, para que la misma seña valga con las dos.
/// No se gira: en las señas importa hacia dónde apunta la mano.
List<double> normalizarMano(List<Punto> puntos, {bool izquierda = false}) {
  assert(puntos.length == puntosPorMano);
  final m = puntos.first; // muñeca
  var escala = 0.0;
  for (final p in puntos) {
    final d = math.sqrt(
      math.pow(p.x - m.x, 2) + math.pow(p.y - m.y, 2) + math.pow(p.z - m.z, 2),
    );
    if (d > escala) escala = d;
  }
  if (escala == 0) escala = 1;
  final espejo = izquierda ? -1.0 : 1.0;
  return [
    for (final p in puntos) ...[
      (p.x - m.x) / escala * espejo,
      (p.y - m.y) / escala,
      (p.z - m.z) / escala,
    ],
  ];
}

/// La misma mano vista en espejo (como si fuera la otra mano). Al grabar
/// una seña se guarda también su espejo, para que valga con las dos manos.
List<double> espejoDe(List<double> mano) => [
  for (var i = 0; i < mano.length; i++) i % 3 == 0 ? -mano[i] : mano[i],
];

enum Pulgar { arriba, abajo }

/// Pulgar arriba o abajo: los otros cuatro dedos doblados y la punta del
/// pulgar bien por encima (o por debajo) de todo lo demás. Sirven de "sí" y
/// "no" aunque nadie le haya enseñado esas señas a NANA. [mano] normalizada.
Pulgar? pulgarDe(List<double> mano) {
  double x(int i) => mano[i * 3];
  double y(int i) => mano[i * 3 + 1];
  double lejos(int i) => math.sqrt(x(i) * x(i) + y(i) * y(i));
  // Dedo doblado: la punta queda más cerca de la muñeca que su nudillo medio.
  const dedos = [(8, 6), (12, 10), (16, 14), (20, 18)];
  for (final (punta, medio) in dedos) {
    if (lejos(punta) > lejos(medio) * 1.1) return null;
  }
  var arriba = true, abajo = true;
  for (var i = 0; i < puntosPorMano; i++) {
    if (i == 4) continue;
    // En la imagen, "y" crece hacia abajo.
    if (y(4) > y(i) - 0.12) {
      arriba = false;
    }
    if (y(4) < y(i) + 0.12) {
      abajo = false;
    }
  }
  return arriba
      ? Pulgar.arriba
      : abajo
      ? Pulgar.abajo
      : null;
}

double _distancia(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    s += d * d;
  }
  return math.sqrt(s);
}

class EjemploSena {
  final String sena;
  final List<double> mano; // ya normalizada, 63 números
  const EjemploSena(this.sena, this.mano);

  Map<String, dynamic> aJson() => {
    'sena': sena,
    // 3 decimales bastan y el archivo pesa mucho menos.
    'mano': [for (final v in mano) (v * 1000).round() / 1000],
  };

  static EjemploSena deJson(Map<String, dynamic> j) => EjemploSena(
    j['sena'] as String,
    [for (final v in j['mano'] as List) (v as num).toDouble()],
  );
}

String ejemplosAJson(List<EjemploSena> ejemplos) =>
    jsonEncode([for (final e in ejemplos) e.aJson()]);

List<EjemploSena> ejemplosDeJson(String texto) {
  if (texto.trim().isEmpty) return [];
  return [
    for (final j in jsonDecode(texto) as List)
      EjemploSena.deJson(j as Map<String, dynamic>),
  ];
}

class ClasificadorSenas {
  final List<EjemploSena> ejemplos;
  // Cuántos vecinos votan y qué tan lejos puede estar el más cercano para
  // contar. Si la mano no se parece a nada, no se adivina.
  final int k;
  final double distanciaMaxima;

  const ClasificadorSenas(
    this.ejemplos, {
    this.k = 5,
    this.distanciaMaxima = 0.9,
  });

  bool get vacio => ejemplos.isEmpty;

  Map<String, int> get cuantosPorSena {
    final m = <String, int>{};
    for (final e in ejemplos) {
      m[e.sena] = (m[e.sena] ?? 0) + 1;
    }
    return m;
  }

  /// La seña que más se parece, o null si ninguna se parece lo suficiente.
  String? clasificar(List<double> mano) {
    if (ejemplos.isEmpty) return null;
    final cercanos = [
      for (final e in ejemplos) (sena: e.sena, d: _distancia(mano, e.mano)),
    ]..sort((a, b) => a.d.compareTo(b.d));
    if (cercanos.first.d > distanciaMaxima) return null;
    final votos = <String, int>{};
    for (final c in cercanos.take(k)) {
      if (c.d > distanciaMaxima) break;
      votos[c.sena] = (votos[c.sena] ?? 0) + 1;
    }
    // Gana la más votada; si empatan, la del vecino más cercano.
    var mejor = cercanos.first.sena;
    for (final MapEntry(key: sena, value: n) in votos.entries) {
      if (n > votos[mejor]!) mejor = sena;
    }
    return mejor;
  }
}

/// Una seña solo cuenta si se sostiene un momento: así no se disparan frases
/// mientras la mano se mueve de una postura a otra.
class SenaSostenida {
  final Duration cuanto;
  SenaSostenida({this.cuanto = const Duration(milliseconds: 900)});

  String? _actual;
  DateTime? _desde;
  bool _avisada = false;

  /// La seña que se está viendo y qué tanto lleva (0 a 1), para dibujarlo.
  String? get viendo => _actual;
  double avance(DateTime ahora) {
    final d = _desde;
    if (d == null || _actual == null) return 0;
    if (_avisada) return 1;
    return (ahora.difference(d).inMilliseconds / cuanto.inMilliseconds).clamp(
      0,
      1,
    );
  }

  /// Se llama con cada cuadro de la cámara. Regresa la seña una sola vez,
  /// cuando ya se sostuvo lo suficiente; para repetirla hay que bajar la
  /// mano o cambiar de seña.
  String? ver(String? sena, DateTime ahora) {
    if (sena != _actual) {
      _actual = sena;
      _desde = sena == null ? null : ahora;
      _avisada = false;
      return null;
    }
    if (sena == null || _avisada) return null;
    if (ahora.difference(_desde!) >= cuanto) {
      _avisada = true;
      return sena;
    }
    return null;
  }
}
