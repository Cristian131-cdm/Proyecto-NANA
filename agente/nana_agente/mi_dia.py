"""«¿Qué me toca hoy?»: lo contesta el código con la lista que capturó la familia.

Ningún modelo escribe esta respuesta, así que no puede inventar una hora ni
una medicina. Solo repite lo que ya está en la lista (título y hora, nunca
dosis): NANA recuerda lo que indicó el médico, no lo decide.
"""

from __future__ import annotations

from .modelos import Peticion, Pendiente
from .reglas import normalizar

# Palabras que dicen de qué tipo de pendiente pregunta.
PISTAS = {
    "medicina": ("pastilla", "medicina", "medicamento", "tomar", "tomo", "tome"),
    "comida": ("comer", "como", "desayun", "comida", "cena", "ceno", "almuerz"),
    "ejercicio": ("caminar", "camino", "ejercicio", "pasear", "salir"),
}

LISTA_VACIA = "Hoy no tengo nada anotado en tu lista. Tu familia lo puede agregar desde su celular."


def _lugar(hora: str) -> str:
    return f"a las {hora}" if hora else "sin hora"


def _juntar(cosas: list[str]) -> str:
    if len(cosas) <= 1:
        return "".join(cosas)
    return ", ".join(cosas[:-1]) + " y " + cosas[-1]


def _por_hora(pendientes: list[Pendiente]) -> str:
    grupos: dict[str, list[str]] = {}
    for p in pendientes:
        grupos.setdefault(p.hora, []).append(p.titulo)
    return _juntar([f"{_lugar(h)} {_juntar(t)}" for h, t in grupos.items()])


def cuales(pet: Peticion) -> tuple[list[Pendiente], bool]:
    """Los pendientes de los que pregunta (por nombre, por tipo o, si no dice, todos)
    y si preguntó por algo en particular."""
    t = f" {normalizar(pet.texto)} "
    por_nombre = [p for p in pet.dia if normalizar(p.titulo) and normalizar(p.titulo) in t]
    if por_nombre:
        return por_nombre, True
    for tipo, pistas in PISTAS.items():
        if any(f" {pista}" in t for pista in pistas):
            de_tipo = [p for p in pet.dia if p.tipo == tipo]
            if de_tipo:
                return de_tipo, True
    return list(pet.dia), False


def contestar(pet: Peticion) -> str:
    if not pet.dia:
        return LISTA_VACIA
    elegidos, en_particular = cuales(pet)
    pendientes = [p for p in elegidos if not p.hecho]
    hechos = [p for p in elegidos if p.hecho]
    partes = []
    if pendientes:
        inicio = "Te toca" if en_particular else "Hoy te toca"
        partes.append(f"{inicio} {_por_hora(pendientes)}.")
    if hechos:
        partes.append(f"Ya está anotado: {_juntar([p.titulo for p in hechos])}.")
    if not pendientes:
        partes.append("Ya no te falta nada de eso por hoy.")
    return " ".join(partes)
