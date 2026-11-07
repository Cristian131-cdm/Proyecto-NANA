# NANA: mejoras para la demo del 10 de noviembre

**Fecha de la sesión:** 7 de noviembre de 2026
**Rama:** `feature/rediseno-accesible` (commits `7a55cdf` a `968e8aa`)
**Pruebas:** 95 pasan (`flutter test`) y `flutter analyze` no marca nada.

## Por qué

El martes 10 de noviembre hay demo de la app. Varias pantallas se veían bien pero eran de mentira:
rutinas, recetas, citas, familia y la semana salían de datos de ejemplo y se perdían al cerrar la app.
Lo que el adulto decía con las frases rápidas no le llegaba a su familia, "Colores más fuertes" no
hacía nada y el cuidador solo se enteraba de una alerta si tenía NANA abierta.

En esta sesión se conectaron esas funciones, se pulieron los dos paneles y se preparó la demo.

## Qué se hizo

### 1. Datos reales en Firestore

| Antes | Ahora |
|---|---|
| Rutinas de ejemplo fijas | Se agregan, editan y borran; se guardan en `adultos/{folio}/rutinas` |
| Recetas de ejemplo | Se guardan en `adultos/{folio}/recetas` |
| Citas de ejemplo, sin forma de agregar | Formulario nuevo "Agregar cita" (día, hora y lugar); se guardan en `adultos/{folio}/citas` |
| Familia de ejemplo (Ana, Luis, Sofía) | La familia real que está vinculada, con su teléfono |
| Interruptores de alertas que se reiniciaban | Se guardan en el campo `reglasAlerta` del adulto |
| Semana con números inventados | Se calcula con los registros de los últimos 7 días |

- El día del adulto ("Toca ahora" y "Todo mi día") usa las rutinas que da de alta la familia, solo los
  días que tocan.
- La semana muestra medicinas a tiempo, cómo se sintió cada día, cuándo dijo que se sentía mal y
  cuántas veces se movió. El día de hoy no cuenta como "faltó" hasta que se vence la medicina.
- `firestore.rules` ahora permite las colecciones `rutinas`, `recetas` y `citas`.

### 2. Alertas para la persona encargada

- **Medicina sin confirmar:** respeta el interruptor de "Familia y alertas".
- **Sin noticias:** alerta nueva si pasan 6, 12 o 24 horas (lo elige la familia) sin ningún registro.
- **Globito rojo** en la pestaña Inicio con el número de alertas, visible desde cualquier pestaña.
- **Frases del adulto:** antes solo decían "Anotado" en su celular. Ahora:
  - Todas se guardan y el cuidador las ve en "Su día" (*Dijo: "¿Viene alguien hoy?"*).
  - Las preocupantes ("Me siento mal", "Me duele algo", "Me siento triste", "Algo me preocupa",
    "Quiero hablar con mi familia") también llegan como alerta, con **Llamar** y **Ya lo vi**.
  - "Ya desayuné / comí / cené" marca esa comida como hecha y "Me siento bien / mal" cuenta como su
    ánimo del día.
  - La lista es fija y está en `lib/core/frases.dart`. No usa IA.
- **Notificación del celular:** si el panel del cuidador está abierto o minimizado y llega una alerta
  nueva (pidió ayuda o dijo algo preocupante), suena una notificación en el canal "Alertas de tu
  familiar". Las alertas que ya estaban al abrir la app no se repiten.

### 3. Visual y accesibilidad

- **Colores más fuertes** ya cambia toda la app: sube el contraste y pone la letra en negritas. Se
  prende en el botón "Aa" de los dos paneles y no te saca de la pantalla en la que estás.
- **Web:** en pantallas anchas NANA se ve como una columna centrada del ancho de un celular. La pestaña
  del navegador tiene el ícono y la descripción de NANA.
- Pantallas vacías con mensajes claros ("Todavía no hay recetas guardadas", "No hay citas próximas").
- "Toca ahora" ya no pide el desayuno en la tarde: una comida o actividad que pasó hace más de 2 horas
  deja de pedirse; una medicina sigue hasta que se confirme.
- Si el celular del adulto no encuentra su cuenta, ya no sale la pantalla roja de error: sale "No pude
  encontrar tu cuenta" con **Intentar de nuevo** y **Entrar con un código**.

### 4. Para la demo

- **Cargar datos de demostración** (panel del cuidador → Mi cuenta): agrega rutinas, una receta, dos
  citas y una semana de ejemplo. No borra nada, no duplica y no toca el día de hoy, para que en vivo se
  vea lo que hace el adulto.
- **Plan B sin internet:** `lib/main_demo.dart` corre NANA sin Firebase, con los datos en memoria.

  ```bash
  flutter run -t lib/main_demo.dart                           # como la cuidadora (Ana)
  flutter run -t lib/main_demo.dart --dart-define=ROL=adulto  # como la persona mayor (Rosa)
  ```

- README nuevo con lo que hace NANA y cómo correrla.

## Archivos nuevos

| Archivo | Para qué |
|---|---|
| `lib/models/rutina.dart` | Rutina: título, tipo, hora y días de la semana |
| `lib/models/receta.dart` | Receta y Cita |
| `lib/core/semana.dart` | Cálculo de los últimos 7 días y el resumen que se comparte |
| `lib/core/frases.dart` | Qué significa cada frase rápida (alerta, comida o ánimo) |
| `lib/core/avisos.dart` | Notificaciones al cuidador y `VigilanteAlertas` |
| `lib/data/demo.dart` | Datos de demostración |
| `lib/main_demo.dart` | NANA sin Firebase |
| `lib/widgets/marco_ancho.dart` | Columna centrada en pantallas anchas |

`RepositorioNana` creció con: `rutinas`, `recetas`, `citas` (leer, guardar, borrar), `reglasAlerta`,
`registrosDesde`, `ultimaActividad` y `avisarFrase`. Las dos versiones (Firebase y memoria) los tienen.

## Cómo probarlo con dos celulares

1. Publicar las reglas: `firebase deploy --only firestore:rules`.
2. Instalar en los dos: `flutter run -d <id de cada celular>` (ver ids con `flutter devices`).
3. En uno entrar como cuidador y cargar los datos de demostración; en el otro entrar como el adulto con
   el código de 6 dígitos.
4. En el del adulto tocar "Ya la tomé", una frase o "Necesito ayuda", y revisar que en el del cuidador
   cambie el Inicio, la Semana y suene la notificación con NANA minimizada.

## Pendiente

- **Publicar las reglas de Firestore** (paso 1 de arriba). Sin eso, rutinas, recetas y citas no se
  guardan en Firebase.
- **Notificaciones con la app cerrada:** necesitan push (Firebase Cloud Messaging + Cloud Functions),
  que requiere el plan Blaze de Firebase. Es la siguiente fase y también la necesita el agente con IA.
- Voz de NANA ("Que me hable"), señas y vibración siguen solo guardados.
- Roles nuevos (varias personas mayores, invitados, encargado suplente): siguiente fase.
- El código para invitar a otro familiar sigue siendo de prueba.
- La hora sale como "10:00 AM" porque la app aún no está configurada en español.

## Límites que se respetaron

NANA solo registra, recuerda y alerta. Las frases y las alertas son listas fijas, sin IA, y ninguna
pantalla da consejos médicos.
