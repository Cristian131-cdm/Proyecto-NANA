// 'pide_ayuda' (botón "Necesito ayuda") o 'frase' (dijo algo preocupante,
// como "Me duele algo"; el texto va en [texto]).
class Alerta {
  final String id;
  final DateTime fecha;
  final bool atendida;
  final String tipo;
  final String? texto;
  // Quién de la familia ya respondió, por uid: «Ya voy» o «Ya la atendí».
  final Map<String, RespuestaAlerta> respuestas;
  // Cómo pidió ayuda: 'boton' (tocó «Necesito ayuda»), 'voz' (lo dijo y
  // confirmó) o 'sin_respuesta' (dijo algo de urgencia y luego no contestó:
  // la más grave, porque puede que no se pueda mover).
  final String como;

  const Alerta({
    required this.id,
    required this.fecha,
    this.atendida = false,
    this.tipo = 'pide_ayuda',
    this.texto,
    this.respuestas = const {},
    this.como = 'boton',
  });

  bool get esFrase => tipo == 'frase';
  bool get noContesto => !esFrase && como == 'sin_respuesta';

  // Para la familia: cómo la pidió, en palabras.
  String get comoSePidio => switch (como) {
    'voz' => 'Pidió ayuda con la voz',
    'sin_respuesta' => 'Dijo que necesitaba ayuda y después no contestó',
    _ => 'Tocó «Necesito ayuda»',
  };

  Alerta copyWith({bool? atendida, Map<String, RespuestaAlerta>? respuestas}) =>
      Alerta(
        id: id,
        fecha: fecha,
        atendida: atendida ?? this.atendida,
        tipo: tipo,
        texto: texto,
        respuestas: respuestas ?? this.respuestas,
        como: como,
      );
}

// Las de «no contestó» primero; luego las más nuevas.
List<Alerta> ordenarAlertas(Iterable<Alerta> alertas) =>
    alertas.toList()..sort((a, b) {
      if (a.noContesto != b.noContesto) return a.noContesto ? -1 : 1;
      return b.fecha.compareTo(a.fecha);
    });

// 'voy' = «Ya voy»; 'atendi' = «Ya la atendí».
class RespuestaAlerta {
  final String nombre;
  final String estado;

  const RespuestaAlerta({required this.nombre, required this.estado});

  bool get atendio => estado == 'atendi';

  Map<String, dynamic> aMapa() => {'nombre': nombre, 'estado': estado};

  static Map<String, RespuestaAlerta> deMapa(Object? m) => {
    if (m is Map)
      for (final MapEntry(:key, :value) in m.entries)
        if (value is Map)
          '$key': RespuestaAlerta(
            nombre: '${value['nombre'] ?? ''}',
            estado: '${value['estado'] ?? 'voy'}',
          ),
  };
}

// Qué avisos quiere la familia (pantalla "Familia y alertas"). "Pide ayuda"
// no está aquí porque siempre se avisa.
class ReglasAlerta {
  final bool medicina;
  final bool sinNoticias;
  final int horasSinNoticias;

  const ReglasAlerta({
    this.medicina = true,
    this.sinNoticias = true,
    this.horasSinNoticias = 12,
  });

  ReglasAlerta copyWith({
    bool? medicina,
    bool? sinNoticias,
    int? horasSinNoticias,
  }) => ReglasAlerta(
    medicina: medicina ?? this.medicina,
    sinNoticias: sinNoticias ?? this.sinNoticias,
    horasSinNoticias: horasSinNoticias ?? this.horasSinNoticias,
  );

  Map<String, dynamic> aMapa() => {
    'medicina': medicina,
    'sinNoticias': sinNoticias,
    'horasSinNoticias': horasSinNoticias,
  };

  static ReglasAlerta deMapa(Map<String, dynamic>? m) => ReglasAlerta(
    medicina: m?['medicina'] as bool? ?? true,
    sinNoticias: m?['sinNoticias'] as bool? ?? true,
    horasSinNoticias: (m?['horasSinNoticias'] as num?)?.toInt() ?? 12,
  );
}
