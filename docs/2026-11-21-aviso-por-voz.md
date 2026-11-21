# Aviso por voz con cuenta regresiva

Diseño del 21 de noviembre de 2026. Solo diseño: nada programado todavía.

## El problema

Hoy, si Rosa dice "me caí" o "ayuda", NANA contesta "Voy a avisarle a tu familia. Confírmalo en la
pantalla" y abre un cuadro con **Sí, avisar / No, cancelar** (`_confirmarAviso` en
`screens/panel_adulto.dart`). Si Rosa se cayó y no alcanza el celular, ese cuadro se queda ahí y
**nadie se entera**. El momento en que más importa el aviso es justo cuando no puede tocar nada.

## La idea

El silencio también cuenta como respuesta. Si NANA oye una urgencia y Rosa no la cancela en
20 segundos, avisa sola a la familia. Cancelar es fácil; quedarse callada también avisa.

## El flujo

```
Rosa: "Me caí y no me puedo mover"
        │  reglas fijas (sin modelo, 0 s) → urgencia
        ▼
Pantalla «Voy a avisar a tu familia» + NANA lo dice en voz alta
        │  escucha 20 s · a los 10 s lo repite
        ├── "sí", "avísales", "ayuda"           → avisa YA
        ├── "estoy bien", "no", toca el botón   → cancela, no avisa
        └── silencio o no se entiende           → al llegar a 0, avisa solo
        ▼
Alerta a toda la familia: «Rosa pidió ayuda por voz» / «…no contestó»
        ▼
NANA: "Ya le avisé a tu familia. Quédate tranquila, ya vienen."
```

## Lo que dice NANA (en voz alta y escrito en grande)

| Momento | NANA dice |
|---|---|
| Al abrir | "Rosa, voy a avisarle a tu familia. Si estás bien, di «estoy bien»." |
| A los 10 s | "Si estás bien, di «estoy bien». Si no, yo les aviso." |
| Avisó | "Ya le avisé a tu familia. Quédate tranquila." |
| Canceló | "Qué bueno que estás bien. Aquí sigo." |
| Sin internet | "No hay internet. Lo mando en cuanto haya." (ya existe: `pedirAyuda` devuelve false y queda en cola) |

## La pantalla

- Fondo de alerta (rojo de `ColoresNana`), letra muy grande.
- Un círculo con los segundos que faltan, que se va vaciando.
- Dos botones de 80 px de alto: **"Avisar ya"** (lleno) y **"Estoy bien"** (contorno).
- La mascota en estado "escuchando".
- Con "Menos movimiento": el círculo no se anima, solo cambia el número.
- Mientras corre, la pantalla no se apaga y el celular vibra cada 5 s.

## Qué cuenta como respuesta

Reconocimiento en el celular, con listas fijas como las de `respuestasRecordatorio` en
`core/voz.dart`. **Nada de modelo**: tiene que funcionar sin internet y en menos de un segundo.

| Rosa dice | Resultado |
|---|---|
| sí · avísales · ayuda · auxilio · ven · no puedo | Avisar ya |
| estoy bien · ya estoy bien · no pasa nada · cancela · fue sin querer | Cancelar |
| "no" a secas | Pregunta otra vez: "¿Estás bien?" (un "no" puede significar "no estoy bien") |
| nada, ruido, quejidos | Sigue contando; a los 0 s avisa |

La regla es: **ante la duda, avisar.** Una falsa alarma le cuesta a la familia una llamada; una
alarma perdida puede costar mucho más.

## Cómo llega a la familia

- Va a **todas** las personas que acompañan a Rosa. "Pidió ayuda" ya no se puede silenciar en
  *Mis alertas*, así que no hace falta escalar de una persona a otra.
- La alerta guarda **cómo** se pidió, para que la familia sepa qué tan grave puede ser:
  - `boton`: tocó "Necesito ayuda".
  - `voz`: lo dijo y confirmó.
  - `sin_respuesta`: dijo algo de urgencia y luego **no contestó**. Este se muestra primero y con más fuerza.
- La tarjeta de la familia trae **Llamar a Rosa** y **Ya voy** (`responderAlerta` ya existe).
  Cuando alguien toca "Ya voy", el celular de Rosa dice: "Tu hija Ana ya viene".
- **NANA nunca marca al 911.** Si hace falta, lo decide la familia (Charter v4: los servicios de
  emergencia quedan fuera del alcance).

## Cambios en el código (cuando se programe)

| Archivo | Cambio |
|---|---|
| `screens/aviso_ayuda.dart` (nuevo) | Pantalla con cuenta regresiva, voz y botones |
| `core/voz.dart` | Lista `respuestasAviso` (avisar / cancelar / no) y su función de entender |
| `screens/panel_adulto.dart` | `_confirmarAviso` abre la pantalla nueva en vez del cuadro |
| `screens/platica_nana.dart` y `nana_escucha.dart` | La acción `ayuda` abre la pantalla nueva |
| `models/alerta.dart` + repositorios | Campo `como` (`boton` / `voz` / `sin_respuesta`) |
| Vista de la familia (`AlertaAyuda`) | Mostrar el `como`; `sin_respuesta` en primer lugar |
| Agente (Fase 4) | La acción `abrir_ayuda` del agente abre la misma pantalla |

Sin cambios en `firestore.rules`: es un campo más dentro de la alerta.

## Pruebas

- Silencio 20 s → se llama `pedirAyuda` con `como: sin_respuesta` (con `Servicios.reloj` falso).
- "Estoy bien" → no se llama `pedirAyuda`.
- "Sí" → avisa antes de terminar la cuenta.
- "No" → vuelve a preguntar; luego silencio → avisa.
- Tocar "Estoy bien" → cancela. Tocar "Avisar ya" → avisa.
- Sin internet → mensaje de cola.
- Letra grande: la pantalla nueva se agrega a `_pantallas` en `test/letra_grande_test.dart`.
- Se agrega a `pantallasConocidas` de `core/medicion.dart`.

## Lo que no resuelve (dicho de frente)

1. **Necesita "Oye NANA" prendido y la app abierta**, como lo decidió Cris (el micrófono no
   escucha siempre). Si el celular está en otro cuarto o bloqueado, no la oye.
2. **Sin push** (plan Blaze), a la familia solo le llega si tiene NANA abierta o minimizada.
3. **Red de seguridad que ya existe:** "sin noticias" (`sinNoticias` en `core/dia.dart`) avisa si
   pasan muchas horas sin ningún registro.
4. **Detectar la caída con los sensores** del celular, sin que hable, queda como trabajo futuro:
   falla si no trae el celular encima, y los wearables están fuera del Charter.

## Decisiones para Cris

1. ¿20 segundos está bien? (los relojes con detección de caídas usan entre 30 y 60).
2. ¿Que se avise solo al llegar a 0, o prefieres que solo vuelva a preguntar?
   Recomiendo avisar solo: es justo el caso de "no se puede mover".
3. ¿El botón grande de "Necesito ayuda" también usa la cuenta regresiva, o ese avisa directo
   porque Rosa ya lo tocó a propósito? Recomiendo que avise directo con 5 s para deshacer.
