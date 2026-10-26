// El adulto mayor que cuida NANA (ADULTO en el diagrama ER).
class Adulto {
  final String folio;
  final String nombre;
  final String apellidos;
  final bool tieneCelular;
  final String? uidAdulto; // null mientras no se vincula su celular
  final List<String> idsCuidadores;
  final String? parentesco; // cómo lo llama quien está viendo: mamá, papá...
  final String? telefono;

  const Adulto({
    required this.folio,
    required this.nombre,
    this.apellidos = '',
    required this.tieneCelular,
    this.uidAdulto,
    this.idsCuidadores = const [],
    this.parentesco,
    this.telefono,
  });

  bool get tieneFamilia => idsCuidadores.isNotEmpty;
}

class CodigoVinculacion {
  final String codigo;
  final String folio;
  final DateTime expira;

  const CodigoVinculacion({
    required this.codigo,
    required this.folio,
    required this.expira,
  });
}
