import '../models/adulto.dart';
import 'semana.dart';

// Quién puede qué con cada persona mayor.
//  - principal: quien la dio de alta. Administra todo.
//  - suplente: lo nombra el principal, por un tiempo o sin fecha de fin.
//  - familiar: entró con una invitación. Acompaña y recibe alertas.
// Lo mismo está en firestore.rules: aquí solo se decide qué se muestra.
enum RolCuidador { principal, suplente, familiar }

RolCuidador rolDe(Adulto a, String? uid, DateTime ahora) {
  if (uid != null && a.creadoPor == uid) return RolCuidador.principal;
  final s = a.suplente;
  if (s != null && s.uid == uid && s.vigente(ahora)) {
    return RolCuidador.suplente;
  }
  return RolCuidador.familiar;
}

class Permisos {
  final RolCuidador rol;
  const Permisos(this.rol);

  factory Permisos.de(Adulto a, String? uid, DateTime ahora) =>
      Permisos(rolDe(a, uid, ahora));

  bool get _principal => rol == RolCuidador.principal;
  bool get _administra => rol != RolCuidador.familiar;

  // Todos confirman una medicina a nombre de la persona y atienden alertas.
  bool get editarMedicinasYRutinas => _administra;
  bool get verSalud => _administra;
  bool get editarSalud => _principal; // salud, recetas y citas
  bool get codigoDelAdulto => _administra;
  bool get invitar => _principal;
  bool get quitarPersonas => _principal;
  bool get nombrarSuplente => _principal;
  bool get cambiarAlertas => _principal;
  bool get pantallaDelAdulto => _principal;
  bool get borrarDatos => _principal;
}

String nombreRol(RolCuidador r) => switch (r) {
  RolCuidador.principal => 'Encargado principal',
  RolCuidador.suplente => 'Suplente',
  RolCuidador.familiar => 'Familiar',
};

// 'sin fecha de fin' o 'hasta el 20 de noviembre de 2026'
String vigenciaSuplente(Suplente s) =>
    s.hasta == null ? 'sin fecha de fin' : 'hasta el ${fechaLarga(s.hasta!)}';

const avisoSoloPrincipal =
    'Eso solo lo puede cambiar quien dio de alta a esta persona.';
