# Registro, vinculación con código, huella y datos reales — diseño

Fecha: 2026-10-25 · Rama: `feature/rediseno-accesible` · Meta: revisión con el profe, viernes 30 oct 2026.
Autoría: Cris (decisiones de producto) con Claude (propuestas técnicas, marcadas como **[decisión de Claude]**).

## 1. Para qué y por qué

Hoy NANA es una maqueta: se entra eligiendo un rol, todo vive en `lib/data/datos_ejemplo.dart` y se
pierde al cerrar la app. Para la revisión del viernes NANA tiene que mostrar lo esencial del proyecto:
**dos celulares de verdad**, el de Rosa (adulta mayor) y el de Ana (su hija), conectados. Rosa toca
"Ya la tomé" y Ana lo ve en segundos.

Quien descarga NANA primero es **la persona encargada**. El adulto mayor no debe escribir correos ni
contraseñas: entra con un código que le da su familiar.

## 2. Metas

1. **Registro del encargado** con correo y contraseña, más un inicio de sesión para quien ya tiene
   cuenta.
2. **Alta del adulto** justo después del registro, con dos preguntas: a quién va a cuidar (nombre y
   parentesco) y si esa persona tiene celular.
3. **Código de vinculación** de 6 números para el celular del adulto ("Entrar con un código").
4. **"Registrarme" para el adulto** que llega sin encargado y usa NANA por su cuenta **[decisión de
   Claude; Cris puede quitarlo]**.
5. **Huella / Face ID** para desbloquear, con la recomendación de activarla una sola vez.
6. **Datos reales en Firestore** de lo que hace falta para la demo: medicamentos, "Ya la tomé", las
   caritas de ánimo y "Avisar a mi familia".
7. **Alarma de la medicina** a su hora, aunque la app esté cerrada (notificación local).
8. **Ajustes guardados** en el celular: tamaño de letra, encuesta hecha y modos de uso.

## 3. Lo que no entra (no-metas)

- El agente de IA y las Cloud Functions. Se platica aparte; necesitan el plan Blaze.
- El push con la app cerrada (FCM). "Avisar a mi familia" llega a Ana **mientras tiene NANA abierta o
  recién minimizada**, no como notificación con la app cerrada.
- La lengua de señas (sigue como pantalla esqueleto).
- Pasar a Firestore las rutinas, las recetas, el historial médico, la lista de familia, las citas y la
  gráfica semanal. Siguen con datos de ejemplo y quedan marcados como siguiente paso.
- Varios cuidadores por adulto con invitación. El modelo lo permite, pero la pantalla de Familia sigue
  siendo de ejemplo.
- La versión física. Está en plática con el equipo y queda fuera del Charter v4.

## 4. Antimetas (si pasa esto, salió mal aunque "funcione")

- Que a Rosa le pidan contraseña o la huella para contestar una alarma de medicina.
- Que alguien que no es de la familia pueda leer los datos de salud de Rosa. Las reglas de Firestore
  no pueden quedar en modo de prueba.
- Fingir un aviso que no llega. Si "Avisar a mi familia" dice "Listo, ya le avisé a Ana", el documento
  ya tiene que estar escrito en Firestore.
- Romper la accesibilidad que ya hay: textos de 18 a 44 pt, botones de 64 px, `Semantics` y nunca
  solo color para dar un estado.
- Que las pruebas dependan de internet o de Firebase.

## 5. Restricciones

- Flutter 3.47.7, Dart ^3.13.5. Proyecto Firebase **`agente-nana`**, plan Spark (gratis), Firestore
  `(default)` en `us-central1`, creado en **modo de producción**.
- La app nunca llama al LLM directamente (regla del proyecto; aquí no aplica todavía).
- Convenciones: nombres en español, una pantalla por archivo en `screens/`, colores siempre con
  `ColoresNana`, widgets privados con `_`.
- Se prueba en el Galaxy A72 de Cris (`R58RA2687DA`). iOS no se puede compilar sin Mac: se deja
  configurado (Info.plist, `flutterfire`), pero sin probar.
- Web: el panel del cuidador debe abrir en web. La huella y la alarma no aplican en web; ahí se omiten
  sin error.

## 6. Flujos (decididos con Cris)

### 6.1 Arranque

Splash → **Arranque** (nueva):
- Sin sesión → **Bienvenida** (reemplaza a `SeleccionRol`, mismos dos botones grandes "Soy adulto
  mayor" / "Soy cuidador o familiar").
- Con sesión → lee `usuarios/{uid}.rol` → `PanelAdulto` o `PanelCuidador`. Si la huella está activada,
  primero va el candado (sección 6.5).

### 6.2 Encargado

"Soy cuidador o familiar" → pantalla con **Crear cuenta** e **Iniciar sesión**.
- Crear cuenta: nombre, apellidos, teléfono, correo, contraseña (mínimo 6 caracteres, regla de
  Firebase). Los errores de Firebase se traducen al español (correo ya usado, contraseña débil, sin
  internet).
- Inicia sesión: correo + contraseña + "Olvidé mi contraseña" (correo de restablecimiento de Firebase).
- Después de crear cuenta, **o si al iniciar sesión no tiene ningún adulto a cargo**, pasa a **Alta del
  adulto**:
  1. "¿A quién vas a cuidar?": nombre, apellidos y parentesco (mamá, papá, abuela, abuelo, tía, tío,
     otro).
  2. "¿{Rosa} tiene celular propio?" Sí / No.
     - **Sí** → pantalla con el **código en grande** (con espacio: `482 913`), "Escribe este código
       en NANA, en el celular de Rosa", botones Copiar y Compartir (share_plus), y la hora de vencimiento.
       Cuando Rosa canjea el código, la pantalla cambia sola a "¡Listo! Rosa ya está conectada" (escucha
       el documento del código).
     - **No** → "Tú llevarás el día de Rosa desde tu celular" y entra al panel. Desde Ajustes del
       cuidador se puede "Generar código para el celular de Rosa" después.
  3. Recomendación de huella (6.5) y luego `PanelCuidador`.

### 6.3 Adulto

"Soy adulto mayor" → dos botones grandes: **Entrar con un código** y **Registrarme**.
- Entrar con un código: teclado numérico, 6 casillas grandes y un botón "Entrar". Errores con texto
  amable: "Ese código no existe o ya venció. Pídele uno nuevo a tu familia."
  Al entrar: "Hola, Rosa. Te conectaste con Ana" → encuesta de apariencia (si no está hecha) →
  recomendación de huella → `PanelAdulto`.
- Registrarme: nombre, apellidos, correo y contraseña (lo mínimo), crea su propio `adultos/{folio}` sin
  cuidadores → encuesta → huella → panel. El botón "Avisar a mi familia" le dice "Todavía no tienes
  familia conectada" en vez de fingir. **[decisión de Claude]**
- La sesión del adulto no se cierra. No hay botón de "Cerrar sesión" a la vista; está escondido en
  Ajustes y pide confirmar.

### 6.4 Rosa sin celular

La hija lleva todo desde su panel: puede marcar "Ya la tomó" por Rosa desde la pestaña de inicio.
Esos registros se guardan con `registradoPor: uid de Ana`.

### 6.5 Huella / Face ID

- Paquete `local_auth`, con `biometricOnly: false` para que, si no hay huella, se use el PIN o patrón
  del celular.
- **Recomendación:** pantalla "¿Quieres entrar con tu huella?" con los botones *Sí, activarla* / *Ahora
  no*. Sale una sola vez por celular (después de vincularse, registrarse o el primer inicio de sesión).
  Si el celular no tiene ningún bloqueo, no sale. También se puede activar o desactivar en Ajustes.
- **Cuándo se pide:** al abrir la app en frío, o al volver a ella después de **30 minutos o más** en
  segundo plano.
- **Cuándo NO se pide:** cuando la app se abre tocando la notificación de una medicina. Ahí va directo a
  `RecordatorioAlarma`. Si desde ahí Rosa quiere ir a su panel, entonces sí se pide.
- Si falla o se cancela: pantalla de candado con la mascota y el botón grande "Desbloquear" para
  reintentar. Nunca se cierra la sesión por fallar.
- La biometría solo desbloquea en ese celular. No es una forma de registro.

### 6.6 Alarma de la medicina

- En el celular del adulto, cada vez que cambia su lista de medicamentos se reprograman las
  notificaciones diarias (`flutter_local_notifications` + `timezone`, `zonedSchedule` con
  `matchDateTimeComponents: time`). Una por medicamento, con el id derivado del id del documento.
- Texto: "Rosa, son las 8:00. Te toca tu Losartán de 50 mg." con las acciones del sistema "Ya me la
  tomé" y "Al rato" en Android, si alcanza el tiempo **[decisión de Claude: opcional]**. Al tocarla se
  abre `RecordatorioAlarma` para ese medicamento.
- Android: pedir permiso de notificaciones (13+) y usar alarma exacta. Si el usuario niega la alarma
  exacta, se usa la inexacta y no se truena la app.
- "Al rato" (o volver a preguntar en 10 min) y la alerta al cuidador cuando se vence la ventana
  **no entran**: la alerta por ventana vencida es lógica de backend (Cloud Functions).

### 6.7 Avisar a mi familia

Rosa confirma → se crea `adultos/{folio}/alertas/{id}` con `tipo: 'pide_ayuda'` → aviso "Listo, ya le
avisé a tu familia". Ana, con el panel abierto, ve la tarjeta roja `_Alerta` que ya existe en
`PestanaInicio`, con "Llamar a Rosa" y "Ya lo atendí", que marca `atendida: true`. Si no se pudo escribir
(sin internet), el aviso dice "No pude avisar. Revisa tu internet o llama a tu familia" y ofrece
llamar. Firestore guarda la escritura sin conexión y la manda después; el texto cuenta esto con
honestidad: "Lo mando en cuanto haya internet".

## 7. Modelo en Firestore

Sigue el ER del equipo (2026-10-22) como diseño lógico. Los nombres de los campos van en español
y en camelCase, como el código.

```
usuarios/{uid}                       ← USUARIOS
  nombre, apellidos, correo, telefono, rol: 'cuidador'|'adulto', estado: 'activo', creado
adultos/{folio}                      ← ADULTO (folio = id automático)
  nombre, apellidos, tieneCelular: bool, uidAdulto: string|null,
  idsCuidadores: [uid]   (para reglas y consultas)
  creadoPor: uid, fechaReg, ultimaActividad
  cuidadores/{uid}                   ← CUIDADOR_ADULTO
    nombre, parentesco, fechaIni, estado: 'activo'
  medicamentos/{id}                  ← RECETAS_MEDICAS (+ hora y ventana)
    nombre, dosis, hora: 'HH:mm', ventanaMin, estado: 'activo'
  registros/{id}                     ← REGISTRO
    tipo: 'medicina'|'comida'|'ejercicio'|'animo', idMedicamento?, titulo,
    valor? (índice de carita 0-4), fecha: timestamp, registradoPor: uid
  alertas/{id}                       ← ALERTAS (con folio implícito por la ruta)
    tipo: 'pide_ayuda', fecha, atendida: bool, atendidaPor?
codigos/{codigo}                     ← código de vinculación
  folio, creadoPor, expira: timestamp (+24 h), usado: bool, usadoPor?
```

Con esto se cierran tres huecos del ER: las alertas saben de qué adulto son por la ruta, el registro
apunta al medicamento (`idMedicamento`) y la receta tiene hora y ventana. El ADULTO ya queda ligado a
su usuario por `uidAdulto`.

**Ajustes de pantalla** (escala de texto, encuesta hecha, modos y huella activada) se guardan **en el
celular** con `shared_preferences`, porque dependen del aparato y no de la persona.

## 8. Autenticación

- Encargado y adulto con "Registrarme": **Firebase Auth con correo y contraseña**.
- Adulto con código: **Firebase Auth anónima** (sesión permanente en ese celular) y luego el canje.
  Se escribe todo en un solo batch, con `usuarios/{uid}` (rol adulto), `adultos/{folio}.uidAdulto = uid`
  y `codigos/{codigo}.usado = true`. Las reglas verifican que el código exista, no esté usado ni vencido
  y que apunte a ese folio. **[decisión de Claude]**
- Riesgo aceptado: si Rosa desinstala la app pierde su usuario anónimo; Ana genera otro código y el
  nuevo canje reemplaza `uidAdulto`.
- Riesgo aceptado: un código de 6 números se podría adivinar por fuerza bruta. Lo mitigan los 24 h
  de vigencia, el uso único y que solo se puede leer un código por id exacto (sin listar). App Check
  queda para después.
- El código se genera al azar en el celular del cuidador y se crea con `set` solo si no existe. Las
  reglas niegan pisar un código ajeno, así que si choca se intenta con otro número (hasta 5 veces).
  **[decisión de Claude]**
- En la consola de Firebase, Cris habilita los proveedores **Correo/contraseña** y **Anónimo**.

## 9. Reglas de seguridad (resumen)

`firestore.rules` en el repo, desplegado con `firebase deploy --only firestore:rules`.
- `usuarios/{uid}`: solo su dueño lee y escribe.
- `adultos/{folio}` y sus subcolecciones: leen y escriben su adulto (`uidAdulto`) y quienes estén en
  `idsCuidadores`. Para crearlo, quien lo crea tiene que ponerse a sí mismo como cuidador o como
  `uidAdulto`.
- `codigos/{codigo}`: `get` para cualquier usuario con sesión; `list` prohibido. Lo crea un cuidador de
  ese folio. Solo se puede actualizar `usado`/`usadoPor` de `false` a `true` antes de `expira`.
- Lo demás está negado.
- La regla de canje que deja al adulto anónimo poner su `uidAdulto` se valida con
  `getAfter()` del código en el mismo batch.

## 10. Cómo se arma por dentro

- **Capa de datos con interfaz:** `RepositorioNana` (abstracta) con `RepositorioFirebase` (real) y
  `RepositorioMemoria` (para pruebas y para correr sin Firebase, sembrada con `DatosEjemplo`). Las
  pantallas reciben el repositorio por un `InheritedWidget` sencillo o un singleton `Servicios`. Así las
  pruebas actuales siguen corriendo sin internet. **[decisión de Claude]**
- Sin Provider, Riverpod ni Bloc: el proyecto usa `ValueNotifier` y `StreamBuilder`, y se sigue igual.
- Paquetes nuevos: `firebase_core`, `firebase_auth`, `cloud_firestore`, `local_auth`,
  `shared_preferences`, `flutter_local_notifications`, `timezone`, `flutter_timezone`.
- Android: `MainActivity` pasa a `FlutterFragmentActivity` (lo pide `local_auth`), se agregan los permisos
  `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED` y los receivers
  de `flutter_local_notifications`, y se activa el desugaring si el paquete lo pide.
- iOS: `NSFaceIDUsageDescription` en `Info.plist`, sin probar (no hay Mac).
- `flutterfire configure --project=agente-nana --platforms=android,ios,web` genera
  `lib/firebase_options.dart`, `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`.
  El repo es público: estas llaves de cliente **no son secretas** (se protegen con las reglas), pero no
  se sube nada de cuentas de servicio.

## 11. Pantallas que cambian

| Archivo | Cambio |
|---|---|
| `screens/seleccion_rol.dart` | Pasa a ser `Bienvenida` (mismos textos) y lleva a los flujos nuevos |
| nuevos en `screens/` | `arranque.dart`, `cuenta_cuidador.dart` (crear/iniciar), `alta_adulto.dart`, `codigo_vinculacion.dart` (mostrar), `entrar_con_codigo.dart`, `registro_adulto.dart`, `recomendar_huella.dart`, `candado.dart` |
| `screens/panel_adulto.dart` | Medicamentos desde Firestore, "Ya la tomé" y las caritas escriben `registros`, "Avisar" escribe `alertas` |
| `screens/pestana_medicamentos.dart` | Lista, alta, edición y borrado contra Firestore |
| `screens/pestana_inicio.dart` | Línea de tiempo con los `registros` de hoy, tarjeta de alerta con las `alertas` sin atender, nombre y teléfono reales |
| `screens/panel_cuidador.dart` | Adultos a cargo reales; Ajustes con huella, generar código y cerrar sesión |
| `core/ajustes.dart` | Carga y guarda con `shared_preferences` |
| `main.dart` | `Firebase.initializeApp`, zona horaria, notificaciones, candado |

## 12. Cómo se verifica

- `flutter analyze` sin errores; `flutter test` pasa con las pruebas viejas (adaptadas a `Bienvenida`)
  más las nuevas: validación del código, flujo de alta con `RepositorioMemoria`, que el candado no se pida
  al venir de la alarma y que se guarden los ajustes.
- Prueba manual en dos dispositivos (A72 + emulador o web para el cuidador): crear cuenta → alta de
  Rosa con celular → código → canjearlo en el A72 → agregar Losartán desde el cuidador → aparece en
  Rosa → "Ya la tomé" → aparece en el cuidador → "Avisar a mi familia" → tarjeta roja en el
  cuidador → cerrar la app 30 min (o bajar el tiempo en modo debug) → pide huella.
- Reglas: probar en el simulador de reglas de la consola, o con el emulador de Firestore si hay
  tiempo, que un usuario ajeno no lee `adultos/{folio}`.

## 13. Lo que decide quien lo construya

El diseño exacto de cada pantalla nueva, dentro del estilo actual. La estructura interna de
`RepositorioNana`. Cómo se derivan los ids de las notificaciones. Los textos de error, que deben ser
cortos, amables y sin jerga.

## 14. Pasos de Cris en la consola (no los puede hacer Claude)

1. Authentication → Comenzar → habilitar **Correo electrónico/contraseña** y **Anónimo**.
2. Aprobar el despliegue de las reglas (`firebase deploy --only firestore:rules`).
3. Probar en su A72.
