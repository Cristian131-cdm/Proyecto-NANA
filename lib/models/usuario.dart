enum Rol { cuidador, adulto }

class Usuario {
  final String uid;
  final String nombre;
  final String apellidos;
  final Rol rol;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.apellidos,
    required this.rol,
  });
}
