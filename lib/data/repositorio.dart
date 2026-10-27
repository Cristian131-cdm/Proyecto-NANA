import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
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
  Future<CodigoVinculacion> generarCodigo(String folio);
  Stream<bool> codigoUsado(String codigo);
  Stream<List<Adulto>> adultosACargo();
  Future<Adulto?> adultoPropio();
  Future<String> nombreDeCuidador(String folio);

  // El día del adulto
  Stream<List<Medicamento>> medicamentos(String folio);
  Future<void> guardarMedicamento(String folio, Medicamento m);
  Future<void> borrarMedicamento(String folio, String id);
  Stream<List<Registro>> registrosDeHoy(String folio);
  Future<void> registrar(String folio, Registro r);

  // Datos de salud (padecimientos, alergias...). Los edita la familia.
  Stream<Salud> salud(String folio);
  Future<void> guardarSalud(String folio, Salud s);

  // Alertas. pedirAyuda devuelve false si quedó en cola por falta de internet.
  Stream<List<Alerta>> alertasSinAtender(String folio);
  Future<bool> pedirAyuda(String folio);
  Future<void> atenderAlerta(String folio, String id);
}
