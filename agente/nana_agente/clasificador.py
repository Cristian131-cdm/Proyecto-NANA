"""El clasificador propio de NANA: Naive Bayes multinomial, solo Python estándar.

Cómo funciona, en corto:
1. Cada frase se convierte en "rasgos": sus palabras, los pares de palabras
   seguidas y trozos de 3 letras de cada palabra. Los trozos hacen que aguante
   errores del dictado ("lozartan" comparte casi todos sus trozos con "losartan").
2. Al entrenar se cuenta cuántas veces sale cada rasgo con cada etiqueta.
3. Para una frase nueva se calcula, para cada etiqueta, qué tan probable es que
   esa frase "venga" de ella (regla de Bayes, con suavizado para lo que nunca
   se vio). Gana la más probable.

Todo se puede abrir y enseñar: el modelo es un JSON con los conteos.
"""

from __future__ import annotations

import math
from collections import Counter, defaultdict
from dataclasses import dataclass

from .reglas import normalizar

# Debajo de esta confianza, NANA dice "no te entendí" en vez de adivinar.
UMBRAL = 0.40
# Si "pregunta_medica" queda en 1.º o 2.º lugar con al menos esto, gana ella
# (lado seguro: es mejor no contestar una pregunta inocente que dar un consejo).
UMBRAL_MEDICA = 0.25
# Lo mismo con "urgencia", y va antes que la médica: "me caí, ¿qué me tomo?"
# es una urgencia. Equivocarse aquí solo abre la pantalla de "Necesito ayuda".
UMBRAL_URGENCIA = 0.35


def rasgos(texto: str) -> list[str]:
    palabras = normalizar(texto).split()
    r = [f"p:{p}" for p in palabras]
    r += [f"b:{a}_{b}" for a, b in zip(palabras, palabras[1:])]
    for p in palabras:
        w = f"#{p}#"
        r += [f"t:{w[i:i + 3]}" for i in range(len(w) - 2)]
    return r


@dataclass(frozen=True)
class Prediccion:
    etiqueta: str
    confianza: float
    probabilidades: tuple[tuple[str, float], ...]
    conocidas: float  # qué parte de las palabras ya había visto el modelo (0 a 1)


class Clasificador:
    def __init__(self, alfa: float = 0.5):
        self.alfa = alfa  # suavizado de Laplace: nada tiene probabilidad cero
        self.frases: Counter[str] = Counter()  # etiqueta -> cuántas frases
        self.cuentas: dict[str, Counter[str]] = defaultdict(Counter)  # etiqueta -> rasgo -> veces
        self._listo()

    def _listo(self):
        self.totales = {e: sum(c.values()) for e, c in self.cuentas.items()}
        self.vocabulario = {r for c in self.cuentas.values() for r in c}

    def entrenar(self, ejemplos) -> "Clasificador":
        """`ejemplos`: pares (frase, etiqueta)."""
        for texto, etiqueta in ejemplos:
            rs = rasgos(texto)
            if not rs:
                continue
            self.frases[etiqueta] += 1
            self.cuentas[etiqueta].update(rs)
        self._listo()
        return self

    @property
    def etiquetas(self) -> list[str]:
        return sorted(self.frases)

    def probabilidades(self, texto: str) -> list[tuple[str, float]]:
        """Cada etiqueta con su probabilidad, de la más a la menos probable."""
        rs = [r for r in rasgos(texto) if r in self.vocabulario]
        if not rs or not self.frases:
            return []
        total_frases = sum(self.frases.values())
        v = len(self.vocabulario)
        puntos = {}
        for e, n in self.frases.items():
            s = math.log(n / total_frases)
            denominador = self.totales[e] + self.alfa * v
            cuenta = self.cuentas[e]
            for r in rs:
                s += math.log((cuenta[r] + self.alfa) / denominador)
            puntos[e] = s
        # Los rasgos de una frase no son independientes (la palabra, sus pares y
        # sus trozos dicen casi lo mismo), y así Naive Bayes sale demasiado
        # seguro. Dividir entre la raíz del número de rasgos lo templa.
        temperatura = math.sqrt(len(rs))
        mayor = max(puntos.values())
        ex = {e: math.exp((s - mayor) / temperatura) for e, s in puntos.items()}
        z = sum(ex.values())
        return sorted(((e, x / z) for e, x in ex.items()), key=lambda par: (-par[1], par[0]))

    def predecir(
        self, texto: str, umbral: float = UMBRAL, umbral_medica: float = UMBRAL_MEDICA
    ) -> Prediccion:
        palabras = normalizar(texto).split()
        if not palabras:
            return Prediccion("no_entendi", 0.0, (), 0.0)
        conocidas = sum(f"p:{p}" in self.vocabulario for p in palabras) / len(palabras)
        probs = tuple(self.probabilidades(texto))
        # Ni una palabra conocida: no adivina por trozos de letras sueltos.
        if not probs or conocidas == 0:
            return Prediccion("no_entendi", 0.0, probs, conocidas)
        # Lado seguro: urgencia primero, luego la médica.
        for segura, minimo in (("urgencia", UMBRAL_URGENCIA), ("pregunta_medica", umbral_medica)):
            for e, p in probs[:2]:
                if e == segura and p >= minimo:
                    return Prediccion(segura, p, probs, conocidas)
        etiqueta, confianza = probs[0]
        if confianza < umbral:
            etiqueta = "no_entendi"
        return Prediccion(etiqueta, confianza, probs, conocidas)

    def a_json(self) -> dict:
        return {
            "alfa": self.alfa,
            "frases": dict(sorted(self.frases.items())),
            "cuentas": {e: dict(sorted(c.items())) for e, c in sorted(self.cuentas.items())},
        }

    @staticmethod
    def de_json(d: dict) -> "Clasificador":
        c = Clasificador(alfa=float(d["alfa"]))
        c.frases = Counter({e: int(n) for e, n in d["frases"].items()})
        c.cuentas = defaultdict(Counter, {e: Counter(v) for e, v in d["cuentas"].items()})
        c._listo()
        return c
