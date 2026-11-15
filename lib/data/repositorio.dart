import '../models/adulto.dart';
import '../models/alerta.dart';
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
const errorYaLaCuidas = 'Ya cuidas a esta persona. No necesitas el código.';

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
