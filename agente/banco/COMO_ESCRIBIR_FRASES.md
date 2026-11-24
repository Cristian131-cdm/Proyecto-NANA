# Cómo escribir frases para entrenar a NANA

NANA aprende a entender a las personas con las frases que escribe el equipo.
Mientras más frases haya y más se parezcan a cómo habla de verdad una persona
mayor, mejor entiende. Hasta el 2026-11-24 todas las escribió la IA («arranque»).

## Cómo se hace (Excel, un archivo por persona)

1. Cris genera una plantilla para cada integrante:

   ```
   cd agente
   python hacer_plantillas.py "<carpeta>" --entrega "viernes 28 de noviembre"
   ```

   Sale `NANA_frases_<Nombre>.xlsx` con cuatro hojas: **Instrucciones**,
   **Frases** (27, la etiqueta ya viene puesta), **Temas** (6) y **Prueba** (5).
2. Cada quien escribe la frase en la celda **amarilla** de cada renglón y le
   regresa el archivo a Cris, **sin cambiarle el nombre**.
3. Cris pone todos los archivos en una carpeta y corre:

   ```
   python juntar_frases.py "<carpeta>" --revisar   (ver qué entraría, sin cambiar nada)
   python juntar_frases.py "<carpeta>"             (agrega, reentrena y corre el banco)
   python -m pytest -q
   ```

   «Frases» va a `entrenamiento.jsonl`, «Temas» a `temas.jsonl` y «Prueba» a
   `frases.jsonl` (el banco de prueba, con el que nunca se entrena). Salta los
   renglones vacíos y el de ejemplo, y avisa de repetidas y etiquetas inválidas.

Reparto por persona: urgencia 5, compañía 5, registro 4, pregunta médica 4,
mi día 4, familia 3, no entendí 2. Con los 7 son ~190 frases nuevas.

## Las etiquetas

| etiqueta | cuándo | ejemplos |
|---|---|---|
| `registro` | dice que **ya hizo** algo de su día, o cómo amaneció de ánimo | «ya me tomé la de la presión», «ya almorcé», «hoy amanecí de buenas» |
| `compania` | quiere platicar, saluda, se siente sola, cuenta algo, pregunta algo que no es de salud | «buenas tardes», «nadie me ha llamado», «¿quién ganó el futbol?» |
| `pregunta_medica` | pregunta qué tomar, cuánto, si puede cambiar o dejar una medicina, o pide un consejo de salud | «¿me tomo otra?», «¿es malo el café con mi pastilla?» |
| `urgencia` | se cayó, le duele algo fuerte, no puede respirar, pide ayuda ya | «me fui de lado y no me puedo parar» |
| `familia` | quiere hablar con alguien de su familia o que le avisen | «márcale a mi Lupe» |
| `mi_dia` | pregunta qué le toca hoy o a qué hora es algo de su lista | «¿qué me toca después de comer?», «¿a qué hora es mi pastilla?» |
| `no_entendi` | pedazos sin sentido que salen del dictado | «este eh», «la que» |

Temas de plática (hoja «Temas»): `saludo`, `soledad`, `tristeza`, `alegria`,
`gracias`, `recuerdos`, `cansancio`, `despedida`, `platica`, `fuera_de_tema`.

## Reglas

- **Como habla de verdad la gente:** «ya me la tomé mija», «ando de malas»,
  «márcale a mi'jo». Con modismos, diminutivos y frases a medias.
- **Variedad:** que no sean la misma frase con una palabra cambiada.
- **Errores del dictado:** algunas con palabras mal oídas («lozartan», «nena»).
- **La frase debe ir con su etiqueta.** Si alguien escribe una frase que no
  corresponde (una de familia en un renglón de urgencia), entrena mal. Al
  juntarlas, conviene leerlas por encima.
- **Nunca copies frases de `frases.jsonl`.** Ese es el banco de *prueba*; si se
  entrena con él, el porcentaje sale inflado y es mentira. `juntar_frases.py` y
  `entrenar.py` lo revisan y no dejan pasar una repetida.

## Las respuestas de NANA

Lo que NANA contesta cuando platica está en `../plantillas/compania.json`, una
lista por tema. Se pueden agregar más; deben ser cortas, cálidas, sin emojis y
**sin consejos de salud**. Las pruebas revisan cada una con el guardián.
Los chistes están en `nana_agente/compania.py` (`CHISTES`), revisados a mano.
