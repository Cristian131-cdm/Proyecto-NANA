# Lo que se hace AHORA (pedido de Cris, 2026-11-18)

Nada de código todavía. Solo dos cosas:

1. **PDF para el equipo** en `C:\Users\cecil\OneDrive\Escritorio\Salle\Proyecto NANA\NANA_plan_agente_y_voz_2026-11-18.pdf`
   con lo que se platicó y lo que se va a hacer: decisiones (API propia con clasificador +
   API externa solo para platicar; «Oye NANA» solo con la app abierta; retro como opción
   con 3 propuestas; agente en las dos vistas), cómo se defiende la dependencia, los pasos
   de los dos planes, el reparto del equipo, las mejoras sugeridas, qué NO se hace y lo que
   falta decidir (pago de la llave, aviso al profesor, elegir estilo retro). Se hace con
   reportlab o HTML + Edge sin ventana (ver notas `gotcha_pdf_windows`, `gotcha_onedrive_pptx`),
   y se revisa con PyMuPDF que no haya texto cortado ni acentos rotos.
2. **Memoria:** copiar este plan completo a `C:\src\nana_app\docs\2026-11-18-plan-agente-y-voz.md`
   (sin commit) y actualizar `project_nana.md` con las decisiones y la ruta del doc, para
   implementar después.

Verificación: abrir el PDF con PyMuPDF, contar páginas y leer el texto de cada una.

---

# NANA — «Oye NANA», plática animada, estilo retro y mejoras (2026-11-18)

## Contexto

Cris aprobó el plan del agente (API propia + API externa solo para platicar) y lo quiere
guardado para después; queda como **Anexo** al final de este archivo. Ahora pide, para la
app: (1) activar a NANA con la voz diciendo «Oye NANA», en la vista del adulto **y** en la
del encargado, **solo mientras la app está abierta** (decisión de Cris el 2026-11-18;
con la app cerrada queda para después); (2) una pantalla donde se vea a NANA
platicando, animada; (3) un estilo **retro** que sugirió un maestro, como **opción en
Apariencia**, con 2-3 propuestas para escoger; (4) mejoras sugeridas.

Lo que ya existe y se reutiliza: `MascotaNana` (`lib/widgets/mascota_nana.dart`) ya mueve
la boca con `Servicios.voz.hablando` y muestra el aro con `escuchando`; `EstadoNana`
(normal, contenta, atenta, dormida); `VozCelular` (`lib/core/voz.dart`, speech_to_text en
el celular + flutter_tts); `entender()` y `NanaEscucha.comandos`; `queSigue` / `queToca()`
(`core/dia.dart`) y `core/semana.dart` para contestar sin IA; `Apariencia`
(`models/apariencia.dart`) + `aplicarApariencia` + `screens/pantalla_del_adulto.dart`.

## Cuándo escucha «Oye NANA»

- **Solo con NANA abierta y en pantalla.** Al minimizar la app, apagar la pantalla o
  abrir otra app, el micrófono se suelta (`AppLifecycleState.paused`) y vuelve al regresar.
  Funciona igual en Android y en iPhone; no hace falta servicio en segundo plano.
- Ícono visible «NANA te escucha» mientras está activo, y un interruptor.
- **Privacidad:** se reconoce dentro del celular, no se graba ni se manda audio. Va
  **apagado por defecto** y se explica en «Tus datos».

## Cómo se hace «Oye NANA»

Detector de palabra de activación **dentro del celular, sin internet ni cuenta**:
reconocedor Vosk con su modelo pequeño de español y una gramática cerrada
(`["oye nana", "[unk]"]`), que solo puede «oír» esa frase. Al detectarla suelta el
micrófono y abre la plática, que usa el `VozCelular` de hoy. Al cerrar la plática vuelve
a escuchar «Oye NANA». Plan B si Vosk no sirve en el A72: Porcupine (Picovoice) con una
palabra personalizada en español (necesita cuenta y llave de Picovoice, gratis para uso
personal). El paso 1 decide con datos.

## Pasos

| # | Qué | Verificación (se pega la salida) |
|---|---|---|
| 0 | Guardar el plan del agente: copiar el Anexo a `docs/2026-11-17-plan-agente.md`, commit de `agente/` + ese doc, y nota de memoria en `project_nana.md` | `git log -1 --stat`; la nota apunta al doc |
| 1 | **Prueba rápida (1 día) en el A72 y el Z Flip 7:** app mínima aparte con Vosk + gramática «oye nana». Medir aciertos (20 veces a 1 m y a 3 m), falsos (10 min de tele/plática de fondo) y si el paquete compila con `flutter test` (ojo con native assets, como pasó con `hand_detection`) | tabla aciertos / falsos / batería en 30 min con la app abierta |
| 2 | `lib/core/despertador.dart`: `Despertador` (interfaz) / `DespertadorVosk` / `DespertadorNulo` (pruebas y web), en `Servicios.despertador`. Coordina el micrófono con `Servicios.voz` (nunca los dos a la vez) | pruebas con `DespertadorNulo` que dispara la frase |
| 3 | **Pantalla «Platicando con NANA»** (`screens/platica_nana.dart`) para el adulto: mascota grande que pasa por *escuchando → pensando → hablando* (agregar estado `pensando` a `EstadoNana`), subtítulos grandes de lo que dice (sirve a quien no escucha), burbujas de lo que se dijo, plática seguida (después de contestar vuelve a escuchar) hasta «gracias NANA», «adiós» o 20 s en silencio. Contesta con lo que ya hay sin IA (`entender()`, `queSigue`, frases); el agente se conecta después en el mismo punto. «Hablar con NANA» y «Oye NANA» abren esta pantalla; `NanaEscucha` se mantiene para tocar frases y señas | `flutter test`; agregarla a `_pantallas` (letra grande) y `pantallasConocidas` |
| 4 | «Oye NANA» con la app abierta (adulto y encargado), interruptor en `pantalla_del_adulto.dart` (campo nuevo `Apariencia.oyeNana`, apagado por defecto) y en Mi cuenta del encargado; ícono visible «NANA te escucha» | prueba a mano en el A72 |
| 5 | Encargado: «Oye NANA» abre «Pregúntale a NANA» con preguntas que se contestan sin IA desde los datos: «¿cómo va mi mamá hoy?» (`queToca`/registros del día), «¿ya se tomó la pastilla?», «¿cómo le fue esta semana?» (`core/semana.dart`). Lo demás: «Eso todavía no lo sé». El agente del encargado (Anexo, paso 9) se conecta aquí | pruebas con `RepositorioMemoria` y datos de `data/demo.dart` |
| 6 | Soltar el micrófono al salir de la app y retomarlo al volver (`WidgetsBindingObserver`), y no escuchar «Oye NANA» durante el recordatorio de medicina ni mientras NANA habla | prueba con ciclo de vida simulado; a mano: minimizar y volver en el A72 |
| 7 | **Estilo retro, 3 propuestas** en una página para enseñar al equipo y al maestro: **A. Tele de los 70** (NANA en una pantalla con perillas que son los botones, crema/café/mostaza), **B. Libreta y teléfono de casa** (tarjetas de papel rayado, botones como teclas de teléfono, madera), **C. Lotería mexicana** (cada botón es una carta con dibujo grande y nombre: «La medicina», «La familia», «La ayuda»). Las tres con contraste y letra que ya pide NANA | el equipo escoge una |
| 8 | Implementar la elegida como `Apariencia.estilo` (`actual` / `retro`): tema y widgets de envoltura (marco, botón, tarjeta) que cambian solo el look de la vista del adulto; la mascota se dibuja dentro del marco retro | `flutter test` + `letra_grande_test` con el estilo retro prendido |
| 9 | Actualizar «Tus datos» y el consentimiento (micrófono para «Oye NANA») | revisión con Cris |

Orden si el tiempo aprieta para la presentación: 0, 1, 3, 4, 6, 7. El 8 espera la
elección del equipo.

## Mejoras que sugiero (Cris decide cuáles)

1. **Probar con cuentas reales** en el A72 / Z Flip 7: principal, suplente, familiar y el
   celular del adulto. Las reglas por papel están desplegadas y nunca se probaron así.
2. **Modo «NANA en la mesa»:** con el celular cargando, NANA se queda grande en pantalla
   como reloj (hora, lo que sigue, la mascota durmiendo). Combina con «Oye NANA» y retro.
3. **«Avisar a mi familia» y alertas reales con push** (necesita Blaze; hoy es lo que más
   falta para el MVP).
4. **El adulto acepta en su propio celular** el aviso de privacidad y ve **quién recibe
   sus alertas** (pendiente de transparencia).
5. **Arreglar la prueba que falla de noche** («El adulto marca su medicina con Ya»).
6. Limpieza: README propio y quitar las plataformas de escritorio que sobran.

## Qué NO hacemos

- «Oye NANA» con la app cerrada o la pantalla apagada (por ahora; en Android se podría
  después con un servicio en primer plano, en iPhone no se puede).
- Grabar o mandar audio: solo se reconoce dentro del celular.
- Cambiar el diseño actual: retro es una opción.
- Conectar el agente con IA en esta etapa (va con el Anexo).

---

# ANEXO — Plan del agente (aprobado el 2026-11-17, para después)

## Cambio del 2026-11-17 (después de revisar el plan con Cris)

Se juntan las dos ideas: **la API propia con el clasificador es la base y siempre
funciona**. Encima, el subagente de **compañía** intenta primero una API externa (Claude
Haiku 5.5) para platicar libre; si la escuela la bloquea, no hay llave o tarda más de
~3 s, contesta con las plantillas propias. Todo lo demás (reglas, orquestador, registro,
guardián capa 1) **nunca** usa la API externa.

```
compañía:  ConRespaldo([ProveedorClaude (solo plática), ProveedorPropio (plantillas)])
todo lo demás:  ProveedorPropio
```

Pasos nuevos (se insertan después del paso 6 de abajo):

| # | Qué | Verificación |
|---|---|---|
| 6a | **Prueba de red en la escuela, lo antes posible:** `agente/probar_red.py` hace una llamada mínima a la API externa y dice "llega / bloqueada / sin llave" en < 10 s. Cris lo corre en el Wi-Fi de la escuela y en el hotspot | salida del script pegada |
| 6b | `ProveedorClaude` en `proveedor.py` con el SDK oficial `anthropic` (leer antes `python/claude-api/README.md` de la skill), `claude-haiku-5-5`, respuestas cortas, llave en la variable `ANTHROPIC_API_KEY` (nunca en el repo, que es público), `stop_reason == "refusal"` → falla y pasa a plantillas | pytest con cliente falso; una llamada real solo con la llave puesta |
| 6c | Guardián para texto de la API externa: `capa_fija` + juez con Haiku (instrucción `SISTEMA_JUEZ` ya escrita). Si el juez no contesta, se rechaza → frase segura. Las plantillas siguen con la lista blanca | pytest: 10 consejos médicos simulados → 10 rechazados |
| 6d | `GET /salud` dice si la API externa está disponible; la terminal marca cada respuesta como `externa` o `propia` | probar con y sin llave |

Lo que se manda a la API externa: solo la frase, el nombre de pila y los últimos turnos
de plática. Nada de medicinas, día, salud ni familia. Hay que agregarlo a "Tus datos" y
al interruptor del encargado.

Pendiente del equipo: la llave de la API necesita saldo (para una prueba basta con unos
pocos dólares: Haiku 5.5 cuesta US$0.10 / 0.50 por millón de tokens). Sin llave, todo
funciona con plantillas.

Si la prueba 6a dice **bloqueada**: se deja `ProveedorClaude` apagado para la demo, se
presenta con la API propia y se explica que en otra red platica libre. No cambia nada más.

## Contexto (plan original, sigue igual salvo lo de arriba)

Decisión del equipo (2026-11-17): en la escuela bloquean las APIs públicas de IA, así que
NANA **no usará Claude, Gemini ni ningún modelo de otra empresa**. Los agentes los escribe
el equipo en código y corren en una API propia. Firebase sí funciona en la escuela.
Tipo de IA elegido por Cris: **clasificador propio** entrenado por el equipo con su banco
de frases, más reglas y respuestas por plantilla. Presentación: esta semana.

Lo que ya existe y se reutiliza (en `C:\src\nana_app\agente`, **sin commit**, 49 pruebas):
la cadena fija `cadena.py` (reglas → orquestador → subagente → guardián), `reglas.py`
(urgencia y pregunta médica sin modelo), `guardian.capa_fija`, `registro.py` (propone,
valida ids, pregunta "¿cuál?"), `servidor_local.py` (la API, con clave y tope diario),
`banco.py` + `correr_banco.py`. La pieza intermedia `ProveedorModelo` hace que el cambio
sea **agregar un proveedor nuevo**, `ProveedorPropio`, sin reescribir la cadena.

**Cómo se defiende ante los maestros:** no depende de ninguna empresa de IA, la plática
nunca sale de su servidor, cuesta $0 y cada respuesta se puede explicar. Lo honesto: la
plática solo cubre los temas para los que el equipo escribió respuestas; lo demás contesta
"de eso no sé". Es un **cambio frente al Charter v4** (que decía "API de un LLM existente,
sin entrenar"): hay que avisarle al profesor. Un clasificador Naive Bayes no es "IA/ML
avanzada", así que sigue fuera de lo excluido.

## Arquitectura

```
Celular (Flutter)                      Laptop del equipo (API propia, Python)
NanaEscucha                            servidor_local.py  POST /agente
  entender() sin IA  ──si no entiende──►  cadena.responder()
  Servicios.agente (AgenteHttp)            0. reglas.py (urgencia / médica)  ← sin cambios
  manda: frase, nombre, su día             1. ClasificadorPropio  (Naive Bayes entrenado)
  recibe: texto + propuesta                2a. registro: emparejador de pendientes
  tarjeta "¿Anoto…?" Sí / No               2b. compañía: plantillas por tema
  (lo anota la app, como hoy)              3. guardián: capa_fija + lista blanca
```

- **Clasificador** (`nana_agente/clasificador.py`, Python estándar, sin paquetes):
  normaliza con `reglas.normalizar`, usa palabras + pares de palabras + trozos de 3 letras
  (aguanta errores del dictado), Naive Bayes multinomial con suavizado. Devuelve etiqueta
  y confianza. Confianza baja → `no_entendi`. Si `pregunta_medica` sale entre las dos
  primeras con confianza razonable, gana `pregunta_medica` (lado seguro). Se entrena con
  `entrenar.py` y se guarda en `modelo/nana.json` (se puede abrir y enseñar).
- **Datos separados:** `banco/entrenamiento.jsonl` (≥ 200 frases, para aprender) y el
  actual `banco/frases.jsonl` (prueba, nunca se entrena con él). Si se entrena con la
  prueba, el porcentaje es mentira.
- **Compañía** (`compania_propia.py` + `plantillas/compania.json`): segundo clasificador
  de temas (saludo, soledad, tristeza, alegría, gracias, familia/recuerdos, cansancio,
  despedida, fuera de tema). Cada tema tiene 3-5 respuestas escritas por el equipo; se
  rota para no repetir la última y se usa el nombre y la hora ("buenas noches, Rosa").
- **Registro:** el emparejador ya está en `ProveedorGuion.conversar`; se mueve a
  `ProveedorPropio` y se mejora con `difflib` (títulos parecidos, "losartan" ≈ "Losartán")
  y alias por tipo (pastilla→medicina, desayuné→comida, caminé→ejercicio). Ánimo por
  palabras ("me siento bien" → 4) con `proponer_animo`. Todo lo que valida hoy
  `registro.py` se queda igual.
- **Guardián capa 2 = lista blanca:** el juez ya no es un modelo; solo aprueba textos que
  estén en las plantillas del equipo o que arme el código (preguntas de confirmación).
  Más una prueba que pasa **todas** las plantillas por `capa_fija`.
- **Red en la demo:** laptop y celular en el **hotspot de un celular** (no depende del
  Wi-Fi de la escuela, que suele aislar aparatos). La URL va por
  `--dart-define=AGENTE_URL=http://<ip>:8787` y la clave por `NANA_CLAVE_DEMO`.
- **Más adelante (cuando se decida Blaze):** como Firebase sí pasa en la escuela, el mismo
  paquete puede subirse como Cloud Function en Python; no usa ninguna API externa.

## Pasos

| # | Qué | Verificación (se pega la salida) |
|---|---|---|
| 1 | Commit de lo que ya existe en `agente/` (rama `feature/voz-senas`) | `git log -1 --stat` |
| 2 | `banco/entrenamiento.jsonl` con ≥ 200 frases por etiqueta + `validar()` que revise que ninguna frase de prueba esté repetida en entrenamiento | `python -m pytest -q` (prueba nueva de no-fuga) |
| 3 | `clasificador.py` + `entrenar.py` → `modelo/nana.json` | pytest: entrena con 5 frases y clasifica una nueva; confianza baja → `no_entendi`; empate con médica → médica |
| 4 | `ProveedorPropio` en `proveedor.py`: orquestador (clasificador), registro (emparejador), compañía (plantillas), juez (lista blanca). `ProveedorGuion` se queda solo para pruebas | `python correr_banco.py --proveedor propio` imprime % por grupo; meta ≥ 80 % y 0 consejo médico |
| 5 | Plantillas de compañía + prueba de que todas pasan `capa_fija` y no tienen emojis | pytest |
| 6 | `servidor_local.py`: proveedor por defecto `propio`; `GET /salud` dice versión del modelo y fecha de entrenamiento | probar con el script de prueba: 4 frases + sin clave → 401 |
| 7 | Flutter: `lib/core/agente.dart` (`Agente`, `AgenteNulo`, `AgenteHttp` con paquete `http` y tiempo límite de 5 s), `Servicios.agente`, enganche en `nana_escucha.dart` solo cuando `entender()` da `null`, tarjeta de confirmación que reutiliza `registrar()` y el ánimo existentes, `urgencia` abre "Necesito ayuda", `abrir_familia` usa `onFamilia`. Cleartext permitido para la IP de la demo (`network_security_config`) | `flutter test` todas pasan con `AgenteFalso`; a mano en el A72 / Z Flip 7 por hotspot |
| 8 | Interruptor "NANA entiende más frases" en la pantalla del adulto del encargado (apagado = flujo de hoy, idéntico) | `flutter test`; con el interruptor apagado no se llama al agente |
| 9 | **Si da tiempo:** agente del encargado. Intenciones (resumen semanal, cuántas veces faltó X, qué pasó tal día, alertas) + extractor de fechas ("hoy", "ayer", "el martes", "esta semana", "este mes") + respuesta con números por plantilla ("faltó 3 de 7 noches"). La app manda solo los datos que ese papel puede ver (`lib/core/permisos.dart`), así el servidor no necesita llaves de Firebase | pytest con datos de ejemplo; familiar no recibe expediente; "¿le subo la dosis?" → frase fija |
| 10 | Ensayo de la demo: hotspot, apagar la laptop en vivo y mostrar que la app sigue (botones, alertas, frases fijas). Documento corto de defensa en `OneDrive\Escritorio\Salle\Proyecto NANA` | ensayo cronometrado |

Mínimo para la presentación: pasos 1-7. El 8 es corto. El 9 es opcional.

## Cómo se reparte el equipo (7 personas)

- **2 personas — frases de entrenamiento** (paso 2): ≥ 200, como hablaría una persona
  mayor, con errores de dictado. **No** escriben las de prueba.
- **1 persona — banco de prueba** (ya hay 30, subirlo a 60) y revisar resultados.
- **1-2 personas — plantillas de compañía** (paso 5): cálidas, cortas, sin consejos.
- **Cris + Claude — Python y Flutter** (pasos 3-4, 6-8).
- **1 persona — defensa y presentación** (paso 10, aviso al profesor del cambio).

## Casos límite

Frase vacía → `no_entendi` sin clasificar. Palabras que el modelo nunca vio → confianza
baja → `no_entendi`. Dictado con errores → trozos de 3 letras. Laptop apagada o sin red →
`AgenteHttp` vence a los 5 s y la app dice la frase fija; todo lo demás sigue igual. Dos
toques seguidos → una sola petición. Tope de 40 turnos al día.

## Qué se puede romper

`NanaEscucha` tiene arreglos delicados de escucha: el agente entra solo en la rama de
"no te entendí" y detrás del interruptor. `test/letra_grande_test.dart` y
`core/medicion.dart` piden registrar pantallas nuevas (`_pantallas`, `pantallasConocidas`)
si la tarjeta de confirmación es pantalla y no hoja. Codex trabaja `panel_cuidador.dart` en
otra rama: el paso 9 puede chocar al juntar.

## Qué NO hacemos

- API externa para clasificar, registrar o decidir algo: solo para platicar.
- Gemini, OpenAI u Ollama (`ProveedorOllama` se queda en el código sin usar).
- Entrenar con datos reales de personas: solo frases escritas por el equipo.
- Desplegar a Cloud Functions esta semana (necesita Blaze).

## Supuestos

Python 3.13 en la laptop de la demo (ya está en la de Cris). El hotspot deja que la laptop
y el celular se vean. Firebase sigue funcionando en la escuela (dicho por Cris).
