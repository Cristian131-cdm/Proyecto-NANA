"""Paso 0: reglas fijas, sin IA.

Lo que suena a urgencia o a pregunta médica se decide aquí, antes de que
cualquier modelo lo vea. Si la lista se equivoca, se equivoca hacia la frase
fija, que es el lado seguro.
"""

import re
import unicodedata


def normalizar(s: str) -> str:
    """Igual que normalizar() en lib/core/voz.dart: '¿Ya me la TOMÉ?' -> 'ya me la tome'."""
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


URGENCIA = (
    "me cai",
    "no me puedo levantar",
    "no puedo levantarme",
    "dolor en el pecho",
    "me duele el pecho",
    "no puedo respirar",
    "me estoy ahogando",
    "me desmaye",
    "estoy sangrando",
    "auxilio",
    "emergencia",
    "ayudenme",
    "ayudame",
    "socorro",
    "ambulancia",
    "me resbale",
    "me pegue en la cabeza",
    "me falta el aire",
    "me voy a desmayar",
    "me siento muy mal",
    "muy mareada",
    "muy mareado",
    "no siento las piernas",
    "no siento el brazo",
    "huele a gas",
    "no me puedo mover",
)

MI_DIA = (
    "que me toca",
    "que toca hoy",
    "a que hora me toca",
    "hora me toca",
    "cuando es mi",
    "tengo pendiente",
    "a que hora tomo",
    "a que hora me tomo",
    "a que hora es mi",
    "a que hora como",
    "a que hora camino",
    "cuando me toca",
    "que tengo hoy",
    "que tengo que hacer",
    "que me falta",
    "que sigue",
    "mi lista",
    "mis pendientes",
)

PREGUNTA_MEDICA = (
    "que medicina me tomo",
    "que medicina tomo",
    "que pastilla me tomo",
    "que pastilla tomo",
    "que me tomo",
    "que tomo para",
    "que es bueno para",
    "cuantas pastillas",
    "cuantas me tomo",
    "cuanto me tomo",
    "puedo tomar",
    "puedo tomarme",
    "me puedo tomar",
    "debo tomar",
    "tomar dos",
    "tomar doble",
    "dejar de tomar",
    "dejo de tomar",
    "dosis",
    "miligramos",
    "sirve para",
    "para que sirve",
    "para que es",
    "que me recetas",
)


def regla_fija(texto: str) -> str | None:
    """Devuelve 'urgencia', 'mi_dia', 'pregunta_medica' o None si hay que preguntarle al orquestador."""
    t = f" {normalizar(texto)} "
    # La urgencia va primero: "me caí, ¿qué me tomo?" es una urgencia.
    for frase in URGENCIA:
        if f" {frase} " in t:
            return "urgencia"
    # Antes que la médica: "¿a qué hora me tomo la pastilla?" pregunta un
    # horario, no un consejo. La respuesta sale de su lista, así que aunque
    # la frase rozara lo médico, NANA solo repite lo que anotó la familia.
    for frase in MI_DIA:
        if f" {frase} " in t:
            return "mi_dia"
    for frase in PREGUNTA_MEDICA:
        if f" {frase} " in t:
            return "pregunta_medica"
    return None
