"""ProveedorPropio: el agente de NANA sin ningún modelo de otra empresa.

Entra en la misma pieza intermedia que cualquier proveedor (`ProveedorModelo`),
así que la cadena (reglas -> orquestador -> subagente -> guardián) no cambia:

- orquestador  -> el clasificador propio (Naive Bayes, modelo/nana.json)
- registro     -> un emparejador: busca en la lista de hoy lo que la persona
                  nombró (aguanta errores de dictado) o el tipo (pastilla,
                  desayuné, caminé), o su ánimo ("amanecí muy bien")
- compañía     -> un segundo clasificador elige el tema y se contesta con una
                  plantilla escrita por el equipo
- juez         -> lista blanca: solo aprueba textos que salieron de las
                  plantillas. Cualquier otro texto se rechaza.
"""

from __future__ import annotations

import datetime as dt
import json
import random
import re
from collections import deque
from typing import Callable

from . import entrenamiento, registro
from .clasificador import Clasificador, Prediccion
from .compania_propia import Plantillas
from .proveedor import Llamada, ProveedorCaido, ProveedorModelo, Salida
from .reglas import normalizar

# Raíz de la palabra dicha -> comida a la que se refiere.
_COMIDAS = (
    ("desayun", "desayuno"), ("almuerz", "almuerzo"), ("almorc", "almuerzo"),
    ("comi", "comida"), ("comer", "comida"), ("cen", "cena"),
    ("merend", "merienda"), ("meriend", "merienda"),
)
_MEDICINA = frozenset(
    "pastilla pastillas medicina medicinas medicamento medicamentos pildora "
    "pildoras chochos tableta tabletas capsula tome".split()
)
_EJERCICIO = ("camin", "ejercicio", "pase", "estir", "gimnas", "bicicl", "nade", "bail")

_ANIMO = (
    (3, ("ni bien ni mal", "regular", "mas o menos", "ahi la llevo", "ahi voy")),
    (1, ("muy mal", "fatal", "pesimo", "de la patada", "horrible")),
    (2, ("no me siento bien", "no estoy bien", "mal", "triste", "desanimada",
         "desanimado", "aguitada", "aguitado", "bajoneada", "bajoneado", "de malas")),
    (5, ("muy bien", "excelente", "de maravilla", "feliz", "contenta", "contento",
         "de lujo", "rebien")),
    (4, ("bien", "de buenas", "de buen humor", "tranquila", "tranquilo")),
)


def emparejar(frase: str, pendientes: list[dict]) -> dict | None:
    """El pendiente de hoy al que se refiere la frase, o None."""
    t = normalizar(frase)
    dichas = t.split()
    # 1. Por nombre: "ya me tomé el losartán" (o "lozartan", si el dictado falla).
    for p in pendientes:
        if registro.menciona(p.get("titulo", ""), frase):
            return p
    # 2. Por tipo: "ya me tomé la pastilla", "ya desayuné", "ya caminé".
    comidas = {c for raiz, c in _COMIDAS if any(d.startswith(raiz) for d in dichas)}
    for p in pendientes:
        tipo = p.get("tipo")
        if tipo == "medicina" and (any(d in _MEDICINA for d in dichas) or "me la tome" in t):
            return p
        if tipo == "ejercicio" and any(d.startswith(r) for d in dichas for r in _EJERCICIO):
            return p
        if tipo == "comida" and comidas:
            del_titulo = {c for raiz, c in _COMIDAS
                          if any(w.startswith(raiz) for w in normalizar(p.get("titulo", "")).split())}
            # "Desayuno" solo cuenta si dijo desayuné; "Comer fruta" sirve para cualquier comida.
            if not del_titulo or del_titulo & comidas:
                return p
    return None


def animo(frase: str) -> int | None:
    """1 muy mal ... 5 muy bien, o None si no habla de cómo se siente."""
    t = f" {normalizar(frase)} "
    for valor, frases in _ANIMO:
        if any(f" {f} " in t for f in frases):
            return valor
    return None


class ProveedorPropio(ProveedorModelo):
    nombre = "propio"

    def __init__(
        self,
        reloj: Callable[[], dt.datetime] = dt.datetime.now,
        azar: random.Random | None = None,
        modelo: tuple[Clasificador, Clasificador, dict] | None = None,
        plantillas: Plantillas | None = None,
    ):
        self.etiquetas, self.temas, self.info = modelo or entrenamiento.cargar()
        self.plantillas = plantillas or Plantillas.cargar(azar=azar)
        self.reloj = reloj
        # Lo que NANA dijo con plantillas: lo único que aprueba el juez.
        self.dichos: deque[str] = deque(maxlen=50)
        self.ultima: Prediccion | None = None

    # ----- orquestador y juez -----

    def estructurado(self, sistema, texto, esquema):
        props = esquema.get("properties", {})
        if "aprobada" in props:
            ok = texto in self.dichos
            return {"aprobada": ok, "motivo": "" if ok else "no salió de las plantillas del equipo"}
        if "etiqueta" in props:
            self.ultima = self.etiquetas.predecir(texto)
            return {"etiqueta": self.ultima.etiqueta}
        raise ProveedorCaido("ProveedorPropio no conoce ese formato")

    # ----- subagentes -----

    def conversar(self, sistema, mensajes, herramientas=()):
        if herramientas:
            return self._registro(mensajes)
        return self._platica(sistema, mensajes)

    def _registro(self, mensajes) -> Salida:
        try:
            datos = json.loads(mensajes[-1]["content"])
        except (ValueError, KeyError, IndexError) as e:
            raise ProveedorCaido("el registro no recibió el JSON esperado") from e
        frase = str(datos.get("frase", ""))
        p = emparejar(frase, list(datos.get("pendientes") or []))
        if p is not None:
            return Salida(llamadas=[Llamada("proponer_registro", {"id": p["id"]})])
        valor = animo(frase)
        if valor is not None:
            return Salida(llamadas=[Llamada("proponer_animo", {"valor": valor})])
        return Salida(texto=registro.NO_ESTA)

    def _platica(self, sistema, mensajes) -> Salida:
        texto = mensajes[-1]["content"] if mensajes else ""
        # compania._sistema() escribe "Se llama Rosa." cuando conoce el nombre.
        m = re.search(r"Se llama ([^.]{1,40})\.", sistema or "")
        nombre = m.group(1).strip() if m else ""
        tema = self.temas.predecir(texto, umbral=0.30).etiqueta
        if tema == "no_entendi":
            tema = "fuera_de_tema"
        respuesta = self.plantillas.elegir(tema, nombre, self.reloj().hour)
        self.dichos.append(respuesta)
        return Salida(texto=respuesta)
