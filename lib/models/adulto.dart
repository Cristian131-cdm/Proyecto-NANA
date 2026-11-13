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

// Alguien de la familia, como lo ve el adulto en "Mi familia".
class Familiar {
  final String uid;
  final String nombre;
  final String? telefono; // null si todavía no lo comparte

  const Familiar({required this.uid, required this.nombre, this.telefono});
}

// Lo que ve el invitado antes de crear su cuenta: a quién va a cuidar y
// quién lo invitó.
class Invitacion {
  final String codigo;
  final String nombreAdulto;
  final String nombreInvita;

  const Invitacion({
    required this.codigo,
    required this.nombreAdulto,
    this.nombreInvita = '',
  });
}

class CodigoVinculacion {
  final String codigo;
  final String folio;
  final DateTime expira;
  // true: invita a un familiar a cuidar. false: vincula el celular del adulto.
  final bool familiar;

  const CodigoVinculacion({
    required this.codigo,
    required this.folio,
    required this.expira,
    this.familiar = false,
  });
}
