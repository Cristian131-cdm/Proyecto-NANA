// 'pide_ayuda' (botón "Necesito ayuda") o 'frase' (dijo algo preocupante,
// como "Me duele algo"; el texto va en [texto]).
class Alerta {
  final String id;
  final DateTime fecha;
  final bool atendida;
  final String tipo;
  final String? texto;

  const Alerta({
    required this.id,
    required this.fecha,
    this.atendida = false,
    this.tipo = 'pide_ayuda',
    this.texto,
  });

  bool get esFrase => tipo == 'frase';
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
