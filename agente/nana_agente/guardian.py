"""El guardián: revisa lo que el modelo quiere decir antes de que se diga.

Capa 1 es código (una lista fija). Capa 2 es un modelo juez con una sola
instrucción. El guardián solo aprueba o rechaza; nunca reescribe. Si el juez
no contesta, se rechaza (falla hacia el lado seguro).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .proveedor import ConRespaldo, ProveedorCaido
from .reglas import normalizar

# Sobre texto ya normalizado (minúsculas, sin acentos ni signos).
_PATRONES = (
    (r"\b\d+\s*(mg|miligramos?|ml|mililitros?|gotas?|tabletas?|pastillas?|capsulas?)\b", "cantidad de medicina"),
    (r"\b(media|una|dos|tres|cuatro)\s+(tabletas?|pastillas?|capsulas?|gotas?|cucharadas?)\b", "cantidad de medicina"),
    (r"\btomate\b", "indica tomar algo"),
    (r"\btoma(r|s)?\s+(una|dos|tres|media|otra|mas|menos|el|la|tu|un)\b", "indica tomar algo"),
    (r"\b(puedes|deberias|debes|te conviene|te recomiendo|te sugiero)\s+(que\s+)?(tomar|tomes|tomarte)\b", "recomienda tomar algo"),
    (r"\b(deja|dejar|dejes|suspende|suspender|suspendas)\s+(de\s+tomar|el|la|tu)\b", "indica dejar una medicina"),
    (r"\b(aumenta|aumentar|sube|subir|subele|baja|bajar|bajale|reduce|reducir|disminuye|disminuir)\b.{0,25}\b(dosis|medicina|pastilla|tratamiento)\b", "cambia la dosis"),
    (r"\bdosis\b", "habla de dosis"),
    (r"\bdiagnostic", "habla de diagnóstico"),
    (r"\b(tienes|padeces|seguro es|parece que tienes|puede ser)\s+(una?\s+)?(diabetes|hipertension|infeccion|gripe|covid|artritis|depresion|ansiedad|anemia|cancer|infarto|embolia|neumonia)\b", "sugiere un padecimiento"),
    (r"\bautomedic", "habla de automedicarse"),
    (r"\bremedio\b", "recomienda un remedio"),
)

# Medicinas comunes: si el modelo nombra una que no está en la lista de la
# persona, se rechaza. No es una lista completa; la capa 2 cubre el resto.
MEDICINAS_COMUNES = frozenset("""
paracetamol ibuprofeno aspirina naproxeno diclofenaco ketorolaco tramadol
metformina insulina glibenclamida losartan enalapril captopril amlodipino
metoprolol atorvastatina simvastatina omeprazol ranitidina pantoprazol
loratadina cetirizina amoxicilina azitromicina ciprofloxacino clonazepam
diazepam alprazolam sertralina fluoxetina levotiroxina warfarina
clopidogrel furosemida hidroclorotiazida prednisona salbutamol tempra
""".split())

ESQUEMA_JUEZ = {
    "type": "object",
    "properties": {
        "aprobada": {"type": "boolean"},
        "motivo": {"type": "string"},
    },
    "required": ["aprobada", "motivo"],
    "additionalProperties": False,
}

SISTEMA_JUEZ = (
    "Revisas una respuesta que una asistente de compañía le va a decir a una "
    "persona mayor. Tu única tarea: decidir si la respuesta da consejo médico. "
    "Rechaza (aprobada=false) si recomienda, ajusta o suspende medicinas, "
    "menciona dosis o cantidades, sugiere un diagnóstico, recomienda remedios "
    "o tratamientos, o interpreta síntomas. Aprueba (aprobada=true) todo lo "
    "que no sea consejo médico: acompañar, animar, preguntar cómo está, "
    "chistes, curiosidades, dichos, plática de su vida o sugerir hablar con "
    "su médico o su familia. No juzgues si es buena plática: solo si es "
    "consejo médico. Ante la duda sobre algo de salud, rechaza. En 'motivo' "
    "escribe una frase corta."
)


@dataclass(frozen=True)
class Veredicto:
    aprobada: bool
    motivo: str = ""
    capa: str = ""  # 'lista' | 'juez' | ''


def capa_fija(texto: str, permitidas: tuple[str, ...] = ()) -> str | None:
    """Motivo del rechazo, o None si la lista fija no encontró nada."""
    t = normalizar(texto)
    for patron, motivo in _PATRONES:
        if re.search(patron, t):
            return motivo
    propias = {p for nombre in permitidas for p in normalizar(nombre).split()}
    for palabra in t.split():
        if palabra in MEDICINAS_COMUNES and palabra not in propias:
            return f"nombra una medicina que no está en su lista ({palabra})"
    return None


def revisar(
    texto: str,
    proveedor: ConRespaldo,
    permitidas: tuple[str, ...] = (),
    limite: float | None = None,
) -> Veredicto:
    if not texto.strip():
        return Veredicto(False, "respuesta vacía", "lista")
    motivo = capa_fija(texto, permitidas)
    if motivo:
        return Veredicto(False, motivo, "lista")
    try:
        r = proveedor.estructurado(SISTEMA_JUEZ, texto, ESQUEMA_JUEZ, limite=limite)
    except ProveedorCaido:
        return Veredicto(False, "el juez no contestó", "juez")
    if not isinstance(r, dict) or r.get("aprobada") is not True:
        motivo = r.get("motivo", "") if isinstance(r, dict) else ""
        return Veredicto(False, str(motivo) or "rechazada por el juez", "juez")
    return Veredicto(True)
