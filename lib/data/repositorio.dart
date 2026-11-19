import '../core/medicion.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/apariencia.dart';
import '../models/medicamento.dart';
import '../models/receta.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../models/salud.dart';
import '../models/usuario.dart';

// Error con un texto que ya se le puede mostrar a la persona tal cual.
class ErrorNana implements Exception {
  final String mensaje;
  const ErrorNana(this.mensaje);

  @override
  String toString() => mensaje;
}

const errorCodigo =
    'Ese código no existe o ya venció. Pídele uno nuevo a tu familia.';

// Hay dos códigos de 6 números y no se pueden cruzar: el del celular del
// adulto y el que invita a un familiar a cuidar.
const errorCodigoFamiliar =
    'Ese código es para un familiar. Regresa, toca "Soy cuidador o familiar" '
    'y luego "Tengo un código de invitación".';
const errorCodigoDelAdulto =
    'Ese código es para el celular de la persona mayor. Pide que te inviten '
    'desde "Familia y alertas".';
const errorSoloEncargado =
    'Solo quien dio de alta a esta persona puede borrar sus datos.';
const errorSinPermiso =
    'Eso solo lo puede hacer quien dio de alta a esta persona.';
const errorYaLaCuidas = 'Ya cuidas a esta persona. No necesitas el código.';
const errorPrincipalNoSale =
    'Tú diste de alta a esta persona. Si ya no la acompañas, usa "Borrar '
    'todos los datos" en Mis ajustes y cuenta.';

// Todo lo que las pantallas leen o escriben. Hay dos versiones:
// RepositorioFirebase (la real) y RepositorioMemoria (pruebas y demo sin internet).
abstract class RepositorioNana {
  String? get uid;
  Future<Usuario?> usuarioActual();

  // Cuentas
  Future<void> crearCuentaCuidador({
    required String nombre,
    required String apellidos,
    required String telefono,
    required String correo,
    required String contrasena,
  });
  Future<void> iniciarSesion(String correo, String contrasena);
  Future<void> restablecerContrasena(String correo);
  Future<void> registrarAdulto({
    required String nombre,
    required String apellidos,
    required String correo,
    required String contrasena,
  });
  Future<Adulto> canjearCodigo(String codigo);
  Future<void> cerrarSesion();

  // Alta y vinculación
  Future<String> altaAdulto({
    required String nombre,
    required String apellidos,
    required String parentesco,
    required bool tieneCelular,
    String? telefono,
  });
  // familiar: true invita a otra persona a cuidar al mismo adulto.
  // El encargado principal deja a alguien de la familia en su lugar: hasta
  // una fecha, o sin fecha de fin (hasta que lo quite). Uno a la vez.
  Future<void> nombrarSuplente(String folio, String uid, {DateTime? hasta});
  Future<void> quitarSuplente(String folio);
  // Saca a alguien de la familia de esta persona (nunca al principal).
  Future<void> quitarFamiliar(String folio, String uid);
  // El familiar o el suplente se sale por su cuenta. El principal no puede
  // (tendría que borrar los datos de la persona).
  Future<void> dejarDeAcompanar(String folio);

  // Cómo se ve NANA en el celular de la persona mayor (lo decide el principal).
  Stream<Apariencia?> apariencia(String folio);
  Future<void> guardarApariencia(String folio, Apariencia a);

  // Estudio de uso, anónimo. El principal lo prende o apaga por persona.
  Future<void> guardarEstudio(String folio, bool activo);
  Future<void> guardarUso(List<EventoUso> lote, {required String rol});
  // Solo para el equipo (lista de administradores del estudio).
  Future<bool> puedeVerEstudio();
  Future<List<EventoUso>> usoReciente();

  // Borra al adulto y todo lo suyo (medicinas, registros, alertas, rutinas,
  // recetas, citas y familia). Solo quien lo dio de alta. No se puede deshacer.
  Future<void> borrarAdulto(String folio);
  Future<CodigoVinculacion> generarCodigo(
    String folio, {
    bool familiar = false,
  });
  // Antes de crear su cuenta, el invitado ve a quién va a cuidar.
  Future<Invitacion> revisarInvitacion(String codigo);
  // Quien tiene cuenta de cuidador canjea la invitación y queda como
  // cuidador de ese adulto.
  Future<Adulto> unirmeComoFamiliar(String codigo, String parentesco);
  Stream<bool> codigoUsado(String codigo);
  Stream<List<Adulto>> adultosACargo();
  Future<Adulto?> adultoPropio();
  Future<String> nombreDeCuidador(String folio);
  // La familia que ve el adulto en "Mi familia", para llamarles.
  Stream<List<Familiar>> familiaDe(String folio);
  // El cuidador deja su teléfono en su fila (las altas viejas no lo tenían).
  Future<void> compartirMiTelefono(String folio);

  // El día del adulto
  Stream<List<Medicamento>> medicamentos(String folio);
  Future<void> guardarMedicamento(String folio, Medicamento m);
  Future<void> borrarMedicamento(String folio, String id);
  Stream<List<Registro>> registrosDeHoy(String folio);
  // Devuelve el id del registro, para poder deshacerlo.
  Future<String> registrar(String folio, Registro r);
  Future<void> borrarRegistro(String folio, String id);

  // Datos de salud (padecimientos, alergias...). Los edita la familia.
  Stream<Salud> salud(String folio);
  Future<void> guardarSalud(String folio, Salud s);

  // Alertas. pedirAyuda devuelve false si quedó en cola por falta de internet.
  Stream<List<Alerta>> alertasSinAtender(String folio);
  Future<bool> pedirAyuda(String folio);
  Future<void> atenderAlerta(String folio, String id);
  // Alguien de la familia responde a «pidió ayuda»: estado 'voy' o 'atendi'.
  // 'atendi' además la marca como atendida para todos.
  Future<void> responderAlerta(String folio, String id, String estado);
  // El adulto dijo algo preocupante ("Me duele algo"): le llega a la familia.
  Future<void> avisarFrase(String folio, String frase);
  Stream<ReglasAlerta> reglasAlerta(String folio);
  Future<void> guardarReglasAlerta(String folio, ReglasAlerta r);

  // Rutinas (comidas y moverse), recetas y citas. Las edita la familia.
  Stream<List<Rutina>> rutinas(String folio);
  Future<void> guardarRutina(String folio, Rutina r);
  Future<void> borrarRutina(String folio, String id);
  Stream<List<Receta>> recetas(String folio);
  Future<void> guardarReceta(String folio, Receta r);
  Future<void> borrarReceta(String folio, String id);
  Stream<List<Cita>> citas(String folio);
  Future<void> guardarCita(String folio, Cita c);
  Future<void> borrarCita(String folio, String id);

  // Para la semana y para "sin noticias".
  Stream<List<Registro>> registrosDesde(String folio, DateTime desde);
  Stream<DateTime?> ultimaActividad(String folio);
}
