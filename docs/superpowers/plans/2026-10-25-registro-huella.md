# Registro, vinculación, huella y datos reales — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que NANA funcione en dos celulares reales: registro del encargado, vinculación del adulto con código, huella, y medicinas / registros / alertas en Firestore.

**Architecture:** Una interfaz `RepositorioNana` con dos implementaciones (`RepositorioMemoria` para pruebas y `RepositorioFirebase` real) accesible por el singleton estático `Servicios`, igual que `Ajustes`. La lógica que no es de UI (armar el día, validar el código, decidir cuándo se pide la huella) son funciones puras con pruebas. Pantallas con `StreamBuilder` y `ValueListenableBuilder`, sin gestor de estado nuevo.

**Tech Stack:** Flutter 3.47.7 · firebase_core, firebase_auth, cloud_firestore · local_auth · shared_preferences · flutter_local_notifications + timezone + flutter_timezone.

**Spec:** `docs/superpowers/specs/2026-10-25-registro-huella-design.md`

## Global Constraints

- Proyecto Firebase `agente-nana`; Firestore `(default)` en `us-central1`; reglas en modo producción.
- Nombres en español; una pantalla por archivo en `lib/screens/`; colores solo vía `ColoresNana`.
- Textos de 18 a 44 pt, botones de 64 px de alto, `Semantics` en botones solo con ícono, nunca solo color.
- Código de vinculación: 6 dígitos, se muestra como `482 913`, vence a las 24 h, un solo uso.
- Huella: se pide en frío o tras ≥ 30 min en segundo plano; nunca al abrir desde la notificación de medicina.
- Las pruebas no usan internet ni Firebase (usan `RepositorioMemoria` y servicios falsos).
- Web debe compilar: huella y alarmas se omiten en web (`kIsWeb`).
- Commits en `feature/rediseno-accesible`, con la línea `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No se hace push sin pedirlo.

## Review Focus

- Sin internet al tocar "Avisar a mi familia" → no debe decir "ya le avisé"; dice "Lo mando en cuanto haya internet" (prueba en Task 7).
- Código con espacios, guiones o menos de 6 dígitos → se normaliza o se rechaza con un texto amable, nunca un crash (Task 3).
- Código vencido o ya usado → "Ese código no existe o ya venció. Pídele uno nuevo a tu familia." (Task 3).
- Cuidador que inicia sesión sin adultos a cargo → va a Alta del adulto, no a un panel vacío que truena (Task 5).
- Volver a la app a los 29 min no pide huella, a los 30 sí; desde la alarma nunca (Task 8).

---

### Task 1: Firebase y paquetes

**Files:**
- Modify: `pubspec.yaml`, `android/app/src/main/kotlin/com/nana/nana_app/MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `ios/Runner/Info.plist`
- Create (generados): `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `firebase.json`

- [ ] **Step 1:** `dart pub global activate flutterfire_cli` y `flutterfire configure --project=agente-nana --platforms=android,ios,web --yes`.
- [ ] **Step 2:** `flutter pub add firebase_core firebase_auth cloud_firestore local_auth shared_preferences flutter_local_notifications timezone flutter_timezone`.
- [ ] **Step 3:** `MainActivity : FlutterFragmentActivity()`; permisos `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` y los receivers de flutter_local_notifications (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`); `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs`. `NSFaceIDUsageDescription` = "NANA usa Face ID para que solo tú abras tu información." en Info.plist.
- [ ] **Step 4:** Verificar: `flutter analyze` sin errores nuevos y `flutter build apk --debug` termina en `Built build\app\outputs\flutter-apk\app-debug.apk`.
- [ ] **Step 5:** Commit "Conecta Firebase (agente-nana) y agrega paquetes de huella y alarmas".

### Task 2: Ajustes guardados

**Files:** Modify `lib/core/ajustes.dart`, `lib/main.dart` · Test `test/ajustes_test.dart`

**Interfaces — Produces:** `Ajustes.cargar() → Future<void>`; cada `ValueNotifier` existente se guarda al cambiar; `Ajustes.encuestaHecha` pasa a `ValueNotifier<bool>`; nuevos `Ajustes.huellaActivada: ValueNotifier<bool>` y `Ajustes.huellaOfrecida: ValueNotifier<bool>`.

- [ ] **Step 1:** Prueba `'Los ajustes sobreviven a reiniciar'`: `SharedPreferences.setMockInitialValues({})`, `await Ajustes.cargar()`, `Ajustes.escalaTexto.value = 1.4`, `Ajustes.encuestaHecha.value = true`, volver a llamar `cargar()` tras poner valores por defecto y comprobar `1.4` y `true`.
- [ ] **Step 2:** Correr `flutter test test/ajustes_test.dart` → FAIL.
- [ ] **Step 3:** Implementar con claves `escala_texto`, `encuesta_hecha`, `que_me_hable`, `con_senas`, `alto_contraste`, `aviso_vibracion`, `huella_activada`, `huella_ofrecida`. `main()` llama a `Ajustes.cargar()` antes de `runApp`. Actualizar los usos de `encuestaHecha` a `.value`.
- [ ] **Step 4:** `flutter test` → todo PASS.
- [ ] **Step 5:** Commit.

### Task 3: Modelos, repositorio en memoria y código

**Files:** Create `lib/data/repositorio.dart` (interfaz + `ErrorNana`), `lib/data/repositorio_memoria.dart`, `lib/core/servicios.dart`, `lib/core/codigo.dart`, `lib/models/adulto.dart`, `lib/models/registro.dart`, `lib/models/alerta.dart`, `lib/models/usuario.dart` · Modify `lib/models/medicamento.dart` (agrega `final String? id`) · Test `test/codigo_test.dart`, `test/repositorio_memoria_test.dart`

**Interfaces — Produces:**
```dart
class ErrorNana implements Exception { final String mensaje; }
enum Rol { cuidador, adulto }
class Usuario { String uid, nombre, apellidos; Rol rol; }
class Adulto { String folio, nombre, apellidos; bool tieneCelular; String? uidAdulto; String? parentesco; String? telefono; }
class Registro { String? id; TipoActividad tipo; String titulo; String? idMedicamento; int? valor; DateTime fecha; String registradoPor; }
class Alerta { String id; DateTime fecha; bool atendida; }
class CodigoVinculacion { String codigo; String folio; DateTime expira; }

abstract class RepositorioNana {
  String? get uid;
  Future<Usuario?> usuarioActual();
  Future<void> crearCuentaCuidador({required String nombre, required String apellidos, required String telefono, required String correo, required String contrasena});
  Future<void> iniciarSesion(String correo, String contrasena);
  Future<void> restablecerContrasena(String correo);
  Future<void> registrarAdulto({required String nombre, required String apellidos, required String correo, required String contrasena});
  Future<Adulto> canjearCodigo(String codigo);
  Future<void> cerrarSesion();
  Future<String> altaAdulto({required String nombre, required String apellidos, required String parentesco, required bool tieneCelular});
  Future<CodigoVinculacion> generarCodigo(String folio);
  Stream<bool> codigoUsado(String codigo);
  Stream<List<Adulto>> adultosACargo();
  Future<Adulto?> adultoPropio();
  Stream<List<Medicamento>> medicamentos(String folio);
  Future<void> guardarMedicamento(String folio, Medicamento m); // id null = nuevo
  Future<void> borrarMedicamento(String folio, String id);
  Stream<List<Registro>> registrosDeHoy(String folio);
  Future<void> registrar(String folio, Registro r);
  Stream<List<Alerta>> alertasSinAtender(String folio);
  Future<bool> pedirAyuda(String folio); // true = ya llegó al servidor; false = quedó en cola sin internet
  Future<void> atenderAlerta(String folio, String id);
}
class Servicios { static RepositorioNana repo = RepositorioMemoria(); }
// lib/core/codigo.dart
String? normalizarCodigo(String texto);   // quita espacios y guiones; null si no son 6 dígitos
String formatearCodigo(String codigo);    // '482913' → '482 913'
String codigoAlAzar(Random r);            // 6 dígitos, permite ceros al inicio
```
`RepositorioMemoria({DateTime Function()? reloj})` sembrado con Rosa (`folio 'rosa'`, parentesco mamá, Losartán 50 mg 8:00, ventana 30) y un usuario cuidador "Ana"; con sesión de Ana por defecto para que las pantallas viejas sigan funcionando.

- [ ] **Step 1:** `codigo_test.dart`: `normalizarCodigo(' 482-913 ') == '482913'`, `normalizarCodigo('48291') == null`, `normalizarCodigo('abc123') == null`, `formatearCodigo('012345') == '012 345'`, `codigoAlAzar` siempre da 6 dígitos (100 corridas con `Random(1)`).
- [ ] **Step 2:** `repositorio_memoria_test.dart`: (a) `altaAdulto` + `generarCodigo` + `canjearCodigo` vincula y `codigoUsado` emite `true`; (b) canjear dos veces lanza `ErrorNana` con `'Ese código no existe o ya venció. Pídele uno nuevo a tu familia.'`; (c) canjear con reloj a +24 h 1 min lanza el mismo error; (d) `pedirAyuda` hace que `alertasSinAtender` emita 1 alerta y `atenderAlerta` la quita.
- [ ] **Step 3:** Correr → FAIL. **Step 4:** Implementar. **Step 5:** Correr todo `flutter test` → PASS. **Step 6:** Commit.

### Task 4: Repositorio de Firebase y reglas

**Files:** Create `lib/data/repositorio_firebase.dart`, `firestore.rules`, `firestore.indexes.json` · Modify `firebase.json`, `lib/main.dart`

**Interfaces — Consumes:** `RepositorioNana` (Task 3). **Produces:** `RepositorioFirebase()`; `main()` hace `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` y `Servicios.repo = RepositorioFirebase()`.

- [ ] **Step 1:** Implementar según el modelo de la sección 7 del spec. Canje en un `WriteBatch` (usuario, `uidAdulto`, código usado). Mapear `FirebaseAuthException.code` a `ErrorNana`: `email-already-in-use` → "Ese correo ya tiene cuenta. Inicia sesión.", `invalid-credential`/`wrong-password`/`user-not-found` → "El correo o la contraseña no coinciden.", `weak-password` → "La contraseña necesita al menos 6 letras o números.", `network-request-failed` → "No hay internet. Revisa tu conexión.". `pedirAyuda` espera la escritura con `timeout(8 s)` y devuelve `false` si vence. `generarCodigo` reintenta hasta 5 veces si el `set` es negado por existir.
- [ ] **Step 2:** `firestore.rules` según la sección 9 del spec (función `esDeLaFamilia(folio)` con `get()` del adulto; canje con `getAfter(/codigos/$(codigo))`).
- [ ] **Step 3:** Verificar: `flutter analyze` limpio; `firebase deploy --only firestore:rules --project agente-nana` **después de que Cris lo apruebe**, salida `Deploy complete!`.
- [ ] **Step 4:** Commit.

### Task 5: Pantallas de cuenta y vinculación

**Files:** Create `lib/screens/arranque.dart`, `cuenta_cuidador.dart`, `alta_adulto.dart`, `codigo_vinculacion.dart`, `entrar_con_codigo.dart`, `registro_adulto.dart` · Rename `seleccion_rol.dart` → `bienvenida.dart` (`class Bienvenida`) · Modify `lib/screens/splash.dart` (va a `Arranque`) · Test `test/cuentas_test.dart`, actualizar `test/widget_test.dart`

**Interfaces — Consumes:** `Servicios.repo`, `normalizarCodigo`, `formatearCodigo`. **Produces:** `Arranque()` decide: sin `uid` → `Bienvenida`; rol cuidador sin adultos → `AltaAdulto`; cuidador → `PanelCuidador`; adulto → encuesta o `PanelAdulto`. Todas pasan por `irConCandado(context, destino)` de Task 8 (en esta task es un `pushReplacement` directo).

- [ ] **Step 1:** Pruebas en `cuentas_test.dart` con `RepositorioMemoria` sin sesión: (a) crear cuenta de cuidador → "¿A quién vas a cuidar?" → nombre "Rosa", parentesco mamá → "¿Rosa tiene celular propio?" → Sí → se ve un texto que coincide con `RegExp(r'^\d{3} \d{3}$')`; (b) en otra prueba, "Soy adulto mayor" → "Entrar con un código" → escribir el código de (a) → "Te conectaste con Ana"; (c) código `'000000'` inexistente muestra el texto de error del spec; (d) cuidador que inicia sesión sin adultos llega a "¿A quién vas a cuidar?".
- [ ] **Step 2:** Correr → FAIL. **Step 3:** Implementar las pantallas (campos de 22 pt, `keyboardType: TextInputType.number` para el código, botón principal deshabilitado hasta tener 6 dígitos). **Step 4:** `flutter test` → PASS (las pruebas viejas cambian `SeleccionRol` por `Bienvenida`; textos iguales). **Step 5:** Commit.

### Task 6: Paneles con datos reales

**Files:** Create `lib/core/dia.dart` · Modify `lib/screens/panel_adulto.dart`, `pestana_inicio.dart`, `pestana_medicamentos.dart`, `panel_cuidador.dart`, `lib/models/actividad.dart` (agrega `final String? idMedicamento`) · Test `test/dia_test.dart`, actualizar `test/botones_test.dart`

**Interfaces — Produces:**
```dart
List<Actividad> diaDelAdulto({required List<Medicamento> meds, required List<Registro> hoy, required List<Actividad> otras, required DateTime ahora});
List<Actividad> lineaDelCuidador({required List<Medicamento> meds, required List<Registro> hoy, required DateTime ahora});
```
Medicamento con registro de hoy → `hecha`; sin registro y `ahora` pasado `hora + ventanaMin` → `sinConfirmar`; el primero no hecho en orden de hora → `ahora`; el resto → `pendiente`. Ordenado por hora.

- [ ] **Step 1:** `dia_test.dart`: Losartán 8:00/30 min sin registro a las 8:40 → `sinConfirmar` en `lineaDelCuidador`; con registro → `hecha`; a las 7:00 en `diaDelAdulto` → `ahora`; las caritas aparecen en la línea del cuidador como `'Ánimo: Bien'` tipo `animo`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar `dia.dart` y conectar las pantallas: adulto usa `adultoPropio()`; cuidador usa `adultosACargo()` (el selector existente de varios adultos). "Ya la tomé" y caritas llaman a `registrar`. Medicamentos con `guardarMedicamento`/`borrarMedicamento`. Cuidador puede marcar "Ya la tomó" por Rosa en la línea de tiempo cuando `tieneCelular == false`. Rutinas, recetas, historial, familia y semana siguen con `DatosEjemplo`.
- [ ] **Step 4:** `flutter test` → PASS. **Step 5:** Commit.

### Task 7: Avisar a mi familia

**Files:** Modify `lib/screens/panel_adulto.dart`, `lib/screens/pestana_inicio.dart` · Test `test/avisar_test.dart`

- [ ] **Step 1:** Pruebas: (a) confirmar aviso con repo normal → "Listo, ya le avisé a tu familia" y `alertasSinAtender` tiene 1; (b) con un repo de prueba cuyo `pedirAyuda` devuelve `false` → "Lo mando en cuanto haya internet"; (c) adulto sin cuidadores → "Todavía no tienes familia conectada" y no se escribe alerta; (d) en `PestanaInicio` con una alerta → se ve la tarjeta y "Ya lo atendí" la quita.
- [ ] **Step 2:** FAIL. **Step 3:** Reemplazar `avisoPendiente` por la llamada a `pedirAyuda`; `PestanaInicio` escucha `alertasSinAtender`. **Step 4:** PASS. **Step 5:** Commit.

### Task 8: Huella / Face ID

**Files:** Create `lib/core/biometria.dart`, `lib/screens/candado.dart`, `lib/screens/recomendar_huella.dart` · Modify `lib/main.dart`, `lib/core/servicios.dart`, flujos de Task 5, Ajustes del cuidador y del adulto · Test `test/huella_test.dart`

**Interfaces — Produces:**
```dart
abstract class Biometria { Future<bool> disponible(); Future<bool> autenticar(String motivo); }
class BiometriaLocal implements Biometria {} // local_auth, biometricOnly: false; en web disponible() = false
bool hayQuePedirHuella({required bool activada, required DateTime? enSegundoPlanDesde, required DateTime ahora, required bool vieneDeAlarma});
const minutosParaBloquear = 30;
Future<void> irConCandado(BuildContext context, Widget destino);
// Servicios.biometria: Biometria = BiometriaLocal()
```
`hayQuePedirHuella` → `false` si `!activada` o `vieneDeAlarma`; `true` si `enSegundoPlanDesde == null` (arranque en frío); si no, `ahora - desde >= 30 min`. Un `WidgetsBindingObserver` en `NanaApp` guarda la hora de `paused` y al `resumed` empuja `Candado` si toca.

- [ ] **Step 1:** Pruebas de `hayQuePedirHuella`: 29 min → false, 30 min → true, frío → true, alarma → false, desactivada → false. Prueba de widget: con una `Biometria` falsa disponible, tras canjear el código aparece "¿Quieres entrar con tu huella?"; "Ahora no" marca `huellaOfrecida` y no vuelve a salir; con biometría no disponible no aparece.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar; `Candado` muestra la mascota y "Desbloquear" (64 px) que reintenta. **Step 4:** PASS. **Step 5:** Commit.

### Task 9: Alarma de la medicina

**Files:** Create `lib/core/alarmas.dart` · Modify `lib/main.dart`, `lib/screens/panel_adulto.dart`, `lib/screens/recordatorio_alarma.dart` · Test `test/alarmas_test.dart`

**Interfaces — Produces:**
```dart
abstract class Alarmas { Future<void> iniciar(void Function(String idMedicamento) alTocar); Future<void> programar(String nombreAdulto, List<Medicamento> meds); }
class AlarmasLocales implements Alarmas {} // en web no hace nada
int idNotificacion(String idMedicamento); // estable, positivo, < 2^31
String textoAlarma(String nombre, Medicamento m); // 'Rosa, son las 8:00. Te toca tu Losartán de 50 mg.'
// Servicios.alarmas: Alarmas = AlarmasLocales()
```
- [ ] **Step 1:** Pruebas: `textoAlarma('Rosa', Losartán 50 mg 8:00)` igual al texto de arriba; `idNotificacion('abc') == idNotificacion('abc')` y en rango. Con unas `Alarmas` falsas, `PanelAdulto` llama a `programar` con la lista de medicamentos al cargar.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar con `zonedSchedule(..., matchDateTimeComponents: DateTimeComponents.time, androidScheduleMode: exactAllowWhileIdle)`, con fallback a `inexactAllowWhileIdle` si no hay permiso de alarma exacta; canal `medicinas` de importancia máxima y payload = id del medicamento. Al tocar, se abre `RecordatorioAlarma` sin candado (`vieneDeAlarma: true`). **Step 4:** PASS. **Step 5:** Commit.

### Task 10: Verificación final

- [ ] `flutter analyze` → `No issues found!`; `flutter test` → todas pasan; `flutter build web` compila.
- [ ] Cris habilita Correo/contraseña y Anónimo en Authentication y aprueba el deploy de reglas.
- [ ] Prueba manual en el A72 (`flutter run -d R58RA2687DA` en su PowerShell) con el guion de la sección 12 del spec.
- [ ] Actualizar la nota de memoria `project_nana.md` con el estado nuevo.
