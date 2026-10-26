// Por ahora el único tipo es 'pide_ayuda' (botón "Avisar a mi familia").
class Alerta {
  final String id;
  final DateTime fecha;
  final bool atendida;

  const Alerta({required this.id, required this.fecha, this.atendida = false});
}
