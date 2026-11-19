# Cómo escribir frases para entrenar a NANA

NANA aprende a entender a las personas con las frases que escribe el equipo.
Mientras más frases haya y más se parezcan a cómo habla de verdad una persona
mayor, mejor entiende.

## Qué hacer

1. Copia `plantilla_frases_equipo.csv` y ábrela en Excel o Google Sheets.
2. Borra las filas de ejemplo y escribe una frase por renglón, con su etiqueta
   y tu nombre en `autor`.
3. Guárdala como **CSV UTF-8** (en Excel: *Guardar como → CSV UTF-8*) y pásala
   a Cris.
4. Cris corre:

   ```
   cd agente
   python entrenar.py --agregar frases_de_ana.csv
   python -m pytest -q
   python correr_banco.py
   ```

## Las etiquetas

| etiqueta | cuándo | ejemplos |
|---|---|---|
| `registro` | dice que **ya hizo** algo de su día, o cómo amaneció de ánimo | «ya me tomé la de la presión», «ya almorcé», «hoy amanecí de buenas» |
| `compania` | quiere platicar, saluda, se siente sola, cuenta algo, pregunta algo que no es de salud | «buenas tardes», «nadie me ha llamado», «¿quién ganó el futbol?» |
| `pregunta_medica` | pregunta qué tomar, cuánto, si puede cambiar o dejar una medicina, o pide un consejo de salud | «¿me tomo otra?», «¿es malo el café con mi pastilla?» |
| `urgencia` | se cayó, le duele algo fuerte, no puede respirar, pide ayuda ya | «me fui de lado y no me puedo parar» |
| `familia` | quiere hablar con alguien de su familia o que le avisen | «márcale a mi Lupe» |
| `no_entendi` | pedazos sin sentido que salen del dictado | «este eh», «la que» |

También se puede hacer el CSV de **temas de plática** con la columna `tema` en
vez de `etiqueta`: `saludo`, `soledad`, `tristeza`, `alegria`, `gracias`,
`recuerdos`, `cansancio`, `despedida`, `platica`, `fuera_de_tema`.

## Reglas

- **Como habla de verdad la gente:** «ya me la tomé mija», «ando de malas»,
  «márcale a mi'jo». Con modismos, diminutivos y frases a medias.
- **Variedad:** que no sean la misma frase con una palabra cambiada.
- **Errores del dictado:** algunas con palabras mal oídas («lozartan», «nena»).
- **Nunca copies frases de `frases.jsonl`.** Ese es el banco de *prueba*; si se
  entrena con él, el porcentaje sale inflado y es mentira. `entrenar.py` lo revisa
  y no deja entrenar si encuentra una repetida.
- Faltan sobre todo frases de **urgencia** y de **compañía**, y en temas, de
  `soledad`, `cansancio` y `alegria`.

## Las respuestas de NANA

Lo que NANA contesta cuando platica está en `../plantillas/compania.json`, una
lista por tema. Se pueden agregar más; deben ser cortas, cálidas, sin emojis y
**sin consejos de salud**. Las pruebas revisan cada una con el guardián.
