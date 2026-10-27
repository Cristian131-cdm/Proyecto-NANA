// Datos de salud del adulto (enf_cronicas, alergias, discapacidad, peso y
// estatura en el ER). Solo lo que indicó un profesional o lo que anotó su familia.
class Salud {
  final List<String> padecimientos;
  final List<String> alergias;
  final List<String> medicamentos; // los que menciona el expediente, sin horario
  final List<String> discapacidades;
  final double? pesoKg;
  final int? estaturaCm;
  final String notas;
  final String origen; // 'manual' o 'documento'
  final DateTime? actualizado;

  const Salud({
    this.padecimientos = const [],
    this.alergias = const [],
    this.medicamentos = const [],
    this.discapacidades = const [],
    this.pesoKg,
    this.estaturaCm,
    this.notas = '',
    this.origen = 'manual',
    this.actualizado,
  });

  static const vacia = Salud();

  static const opcionesDiscapacidad = [
    'No ve bien',
    'No oye bien',
    'No habla',
    'Daltonismo',
    'Movilidad reducida',
  ];

  bool get estaVacia =>
      padecimientos.isEmpty &&
      alergias.isEmpty &&
      medicamentos.isEmpty &&
      discapacidades.isEmpty &&
      pesoKg == null &&
      estaturaCm == null &&
      notas.isEmpty;

  Salud copyWith({
    List<String>? padecimientos,
    List<String>? alergias,
    List<String>? medicamentos,
    List<String>? discapacidades,
    double? Function()? pesoKg,
    int? Function()? estaturaCm,
    String? notas,
    String? origen,
    DateTime? actualizado,
  }) => Salud(
    padecimientos: padecimientos ?? this.padecimientos,
    alergias: alergias ?? this.alergias,
    medicamentos: medicamentos ?? this.medicamentos,
    discapacidades: discapacidades ?? this.discapacidades,
    pesoKg: pesoKg != null ? pesoKg() : this.pesoKg,
    estaturaCm: estaturaCm != null ? estaturaCm() : this.estaturaCm,
    notas: notas ?? this.notas,
    origen: origen ?? this.origen,
    actualizado: actualizado ?? this.actualizado,
  );

  Map<String, dynamic> aMapa() => {
    'padecimientos': padecimientos,
    'alergias': alergias,
    'medicamentos': medicamentos,
    'discapacidades': discapacidades,
    'pesoKg': pesoKg,
    'estaturaCm': estaturaCm,
    'notas': notas,
    'origen': origen,
  };

  factory Salud.deMapa(Map<String, dynamic>? m) {
    if (m == null) return vacia;
    List<String> lista(String clave) =>
        List<String>.from(m[clave] as List? ?? const []);
    return Salud(
      padecimientos: lista('padecimientos'),
      alergias: lista('alergias'),
      medicamentos: lista('medicamentos'),
      discapacidades: lista('discapacidades'),
      pesoKg: (m['pesoKg'] as num?)?.toDouble(),
      estaturaCm: (m['estaturaCm'] as num?)?.toInt(),
      notas: m['notas'] as String? ?? '',
      origen: m['origen'] as String? ?? 'manual',
    );
  }
}
