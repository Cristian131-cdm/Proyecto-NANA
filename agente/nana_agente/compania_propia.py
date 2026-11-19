"""Compañía sin modelo: respuestas escritas por el equipo, una lista por tema.

El tema lo decide el segundo clasificador (banco/temas.jsonl). Las respuestas
viven en plantillas/compania.json y pueden usar {nombre} y {saludo}
("Buenos días", "Buenas tardes" o "Buenas noches", según la hora).
"""

from __future__ import annotations

import json
import random
from pathlib import Path

ARCHIVO = Path(__file__).resolve().parent.parent / "plantillas" / "compania.json"


def saludo_por_hora(hora: int) -> str:
    if 5 <= hora < 12:
        return "Buenos días"
    if 12 <= hora < 19:
        return "Buenas tardes"
    return "Buenas noches"


class Plantillas:
    def __init__(self, respuestas: dict[str, list[str]], azar: random.Random | None = None):
        self.respuestas = respuestas
        self.azar = azar or random.Random()
        self._ultima: dict[str, int] = {}

    @staticmethod
    def cargar(archivo: Path = ARCHIVO, azar: random.Random | None = None) -> "Plantillas":
        datos = json.loads(archivo.read_text(encoding="utf-8"))
        return Plantillas({t: list(r) for t, r in datos.items() if not t.startswith("_")}, azar)

    @staticmethod
    def llenar(plantilla: str, nombre: str, hora: int) -> str:
        if not nombre:
            # "Hola, {nombre}." sin nombre queda "Hola."
            plantilla = plantilla.replace(", {nombre}", "").replace(" {nombre}", "")
        return plantilla.replace("{nombre}", nombre).replace("{saludo}", saludo_por_hora(hora))

    def elegir(self, tema: str, nombre: str, hora: int) -> str:
        opciones = self.respuestas.get(tema) or self.respuestas["fuera_de_tema"]
        indices = list(range(len(opciones)))
        # No repite la última respuesta que dio en ese tema.
        if len(indices) > 1 and tema in self._ultima:
            indices.remove(self._ultima[tema])
        i = self.azar.choice(indices)
        self._ultima[tema] = i
        return self.llenar(opciones[i], nombre, hora)
