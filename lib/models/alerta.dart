// Por ahora el único tipo es 'pide_ayuda' (botón "Avisar a mi familia").
class Alerta {
  final String id;
  final DateTime fecha;
  final bool atendida;

  const Alerta({required this.id, required this.fecha, this.atendida = false});
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
