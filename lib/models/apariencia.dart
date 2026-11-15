// Cómo quiere el encargado que se vea NANA en el celular de la persona
// mayor. El celular lo aplica una vez por cada cambio; después la persona
// puede ajustarlo en "Aa" y se respeta hasta que el encargado lo cambie otra vez.
class Apariencia {
  final double escalaTexto; // 1.0, 1.25 o 1.5
  final bool altoContraste;
  final bool queMeHable;
  final bool menosMovimiento;
  final DateTime? actualizado;

  const Apariencia({
    this.escalaTexto = 1.0,
    this.altoContraste = false,
    this.queMeHable = false,
    this.menosMovimiento = false,
    this.actualizado,
  });

  Apariencia copyWith({
    double? escalaTexto,
    bool? altoContraste,
    bool? queMeHable,
    bool? menosMovimiento,
    DateTime? actualizado,
  }) => Apariencia(
    escalaTexto: escalaTexto ?? this.escalaTexto,
    altoContraste: altoContraste ?? this.altoContraste,
    queMeHable: queMeHable ?? this.queMeHable,
    menosMovimiento: menosMovimiento ?? this.menosMovimiento,
    actualizado: actualizado ?? this.actualizado,
  );

  Map<String, dynamic> aMapa() => {
    'escalaTexto': escalaTexto,
    'altoContraste': altoContraste,
    'queMeHable': queMeHable,
    'menosMovimiento': menosMovimiento,
    'actualizado': actualizado?.millisecondsSinceEpoch,
  };

  static Apariencia? deMapa(Map<String, dynamic>? m) {
    if (m == null) return null;
    final ms = m['actualizado'];
    return Apariencia(
      escalaTexto: (m['escalaTexto'] as num?)?.toDouble() ?? 1.0,
      altoContraste: m['altoContraste'] == true,
      queMeHable: m['queMeHable'] == true,
      menosMovimiento: m['menosMovimiento'] == true,
      actualizado: ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
    );
  }
}
