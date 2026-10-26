import 'actividad.dart';

// Algo que el adulto (o su familia por él) dejó anotado: REGISTRO en el ER.
class Registro {
  final String? id;
  final TipoActividad tipo;
  final String titulo;
  final String? idMedicamento;
  final int? valor; // índice de CaritasAnimo cuando tipo == animo
  final DateTime fecha;
  final String registradoPor;

  const Registro({
    this.id,
    required this.tipo,
    required this.titulo,
    this.idMedicamento,
    this.valor,
    required this.fecha,
    required this.registradoPor,
  });
}
