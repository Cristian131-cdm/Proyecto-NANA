# NANA: mejoras de diseño, animación e interacción

**Fecha:** 9 de noviembre de 2026
**Rama:** `feature/rediseno-accesible` (commits `e236bb9` a `44018b0`)
**Pruebas:** 100 pasan (`flutter test`) y `flutter analyze` no marca nada.

## Por qué

Después de dejar lista la demo, se propusieron mejoras de diseño, animaciones, acciones más interactivas
y botones que se entiendan solos en los dos roles. También se decidió que NANA sea **apta para todos**
con diseño universal: sigue pensada para personas mayores (el Charter v4 no cambia), pero cualquiera la
puede usar sin problema, incluidas personas con discapacidad, cuidadores jóvenes y quien tiene poca
experiencia con celulares.

De la lista de propuestas se hicieron las 6 mejoras rápidas que no tocan la base de datos.

## Qué se hizo

### 1. Español de verdad

- Se agregó `flutter_localizations` con `es_MX`.
- La hora sale como "10:00 a. m." y el calendario y el selector de hora están en español (antes salían en
  inglés).

### 2. "Ya me la tomé" con festejo y botón Deshacer

- Al marcar algo como hecho sale una palomita que se dibuja, el celular vibra y aparece "¡Muy bien!
  Anoté tu medicina". Se cierra solo.
- Después sale un aviso con **Deshacer** durante 5 segundos, por si fue un error de dedo. Funciona al
  marcar algo hecho, al anotar el ánimo, cuando el cuidador confirma por el adulto y al borrar una
  medicina.

### 3. NANA con cara según el día

| Estado | Cuándo |
|---|---|
| Contenta (ojos felices y sonrisa grande) | Ya hizo todo lo del día |
| Atenta (ojos grandes y boca en "o") | Algo ya le toca, aunque sea de noche |
| Dormida (ojos cerrados) | De 10 pm a 6 am si no hay nada pendiente |
| Normal | El resto del día |

- El lector de pantalla dice el estado ("NANA está contenta: hiciste todo lo de hoy").
- La tarjeta "Toca ahora" se desliza suave a la siguiente actividad en vez de brincar.

### 4. Anillo de progreso y tarjetas mientras carga

- En el panel del cuidador, la inicial del adulto tiene un **anillo que se llena** con lo que lleva hoy
  (medicinas, comidas y actividad). Al completar todo se pone verde con una palomita. El lector de
  pantalla dice "Rosa: lleva 3 de 5 hoy".
- Mientras carga, en lugar del circulito que gira salen **tarjetas grises que laten** con la forma de la
  pantalla.

### 5. Apta para todos y botones que dicen qué hacen

- Ajuste nuevo **"Menos movimiento"**: apaga las animaciones de toda la app, además de lo que diga el
  celular.
- El botón **"Aa" del cuidador** ahora muestra las opciones que sirven a cualquiera: tamaño de letra,
  colores más fuertes y menos movimiento.
- Los botones dicen qué hacen: "Ya me la tomé" o "Ya lo hice" (antes solo "Ya"); el cuidador confirma
  con "Sí, ya se la tomó" o "Todavía no" (antes "Sí, ya" y "No").
- Todos los botones que solo tienen ícono ya tenían nombre para el lector de pantalla.

### 6. Tocar un día de la Semana

- Cada día de la gráfica y de las caritas se puede tocar. Se abre una hoja con el día (por ejemplo
  "Jueves 5 de noviembre"): medicinas, ánimo y cada cosa que se anotó con su hora.
- Las barras de la gráfica suben al abrir la pestaña.

Todas las animaciones se quedan quietas con "Menos movimiento" o con la opción del celular.

## Bug que encontraron las pruebas

En la versión sin internet (`main_demo.dart`), volver a guardar una medicina borrada tronaba la app, que
es justo lo que hace "Deshacer". Ya está arreglado en `RepositorioMemoria.guardarMedicamento`.

## Archivos nuevos y cambios técnicos

| Archivo | Para qué |
|---|---|
| `lib/widgets/festejo.dart` | Palomita animada con vibración |
| `lib/widgets/esqueleto.dart` | Tarjetas grises mientras carga |
| `test/mejoras_test.dart` | Pruebas de las mejoras |

- `RepositorioNana.registrar()` ahora devuelve el id del registro y hay `borrarRegistro()`.
- `MascotaNana` tiene `EstadoNana`; `estadoNana()` en `core/dia.dart` decide cuál toca.
- `AnilloDelDia` en `panel_cuidador.dart`; `Ajustes.menosMovimiento`; `mostrarAjustesTexto(paraCuidador: true)`.
- `DiaSemana.registros` y `mostrarDetalleDia()` en `pestana_semana.dart`.
- `mostrarAviso(..., onDeshacer:)` en `widgets/aviso.dart`.

## Cómo probarlo

Correrlo en cada celular por su id (no usar `-d all`, porque intenta compilar para Windows y pide Visual
Studio):

```bash
flutter run -d R5CY70SN3TA
flutter run -d R58RA2687DA
```

1. Adulto: tocar "Ya me la tomé" y revisar la palomita, la vibración y "Deshacer".
2. Adulto: ver que la cara de NANA cambie cuando algo ya toca y al terminar todo.
3. Cuidador: ver el anillo, tocar un día en la Semana y prender "Menos movimiento" en "Aa".
4. Agregar una cita y revisar que el calendario salga en español.

## Pendiente

- **La familia le contesta al adulto** ("Ya voy", "Te llamo en un rato", "💜 Un abrazo"): espera el
  modelo de base de datos.
- Del resto de la lista: modo oscuro, recorrido de la primera vez, botón "?" en el cuidador, "Necesito
  ayuda" manteniendo presionado (decidir con el equipo), colores seguros para daltonismo, uso con una mano,
  inglés y la voz de NANA.
- Publicar las reglas de Firestore (`firebase deploy --only firestore:rules`) si no se ha hecho.
