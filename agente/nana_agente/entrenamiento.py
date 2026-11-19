"""Las frases con las que aprende el clasificador y el modelo ya entrenado.

Hay dos archivos de entrenamiento, separados del banco de prueba:
    banco/entrenamiento.jsonl   frase -> etiqueta (registro, compania, ...)
    banco/temas.jsonl           frase -> tema de plática (saludo, soledad, ...)
El banco de prueba (banco/frases.jsonl) NUNCA se usa para entrenar: si se
entrena con la prueba, el porcentaje que sale es mentira.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

from .clasificador import Clasificador
from .frases_fijas import ETIQUETAS
from .reglas import normalizar

RAIZ = Path(__file__).resolve().parent.parent
ETIQUETAS_ARCHIVO = RAIZ / "banco" / "entrenamiento.jsonl"
TEMAS_ARCHIVO = RAIZ / "banco" / "temas.jsonl"
MODELO = RAIZ / "modelo" / "nana.json"

TEMAS = (
    "saludo", "soledad", "tristeza", "alegria", "gracias", "recuerdos",
    "cansancio", "despedida", "platica", "fuera_de_tema",
)
MINIMO_POR_ETIQUETA = 15
MINIMO_POR_TEMA = 8
META = 200  # frases de entrenamiento que pide el plan (aviso, no error)


def _leer(archivo: Path, campo: str) -> list[dict]:
    filas = []
    for n, linea in enumerate(archivo.read_text(encoding="utf-8").splitlines(), 1):
        if not linea.strip():
            continue
        fila = json.loads(linea)
        fila["linea"] = n
        fila.setdefault(campo, "")
        filas.append(fila)
    return filas


def leer_etiquetas(archivo: Path = ETIQUETAS_ARCHIVO) -> list[dict]:
    return _leer(archivo, "etiqueta")


def leer_temas(archivo: Path = TEMAS_ARCHIVO) -> list[dict]:
    return _leer(archivo, "tema")


def validar(
    etiquetas: list[dict], temas: list[dict], prueba: list[dict],
    minimo: int = MINIMO_POR_ETIQUETA, minimo_tema: int = MINIMO_POR_TEMA,
) -> list[str]:
    errores = []
    de_prueba = {normalizar(c["frase"]): c.get("linea") for c in prueba}
    for nombre, filas, campo, validas, menos in (
        ("entrenamiento.jsonl", etiquetas, "etiqueta", ETIQUETAS, minimo),
        ("temas.jsonl", temas, "tema", TEMAS, minimo_tema),
    ):
        vistas: dict[str, int] = {}
        for f in filas:
            donde = f"{nombre} línea {f.get('linea')}"
            frase = normalizar(str(f.get("frase", "")))
            if not frase:
                errores.append(f"{donde}: falta la frase")
                continue
            if f[campo] not in validas:
                errores.append(f"{donde}: {campo} desconocido {f[campo]!r}")
            if frase in de_prueba:
                errores.append(f"{donde}: «{f['frase']}» está en el banco de prueba (línea {de_prueba[frase]})")
            if frase in vistas:
                errores.append(f"{donde}: repetida (ya está en la línea {vistas[frase]})")
            vistas[frase] = f.get("linea")
        for v in validas:
            n = sum(f[campo] == v for f in filas)
            if n < menos:
                errores.append(f"{nombre}: {campo} {v!r} tiene {n} frases (mínimo {menos})")
    return errores


def huella() -> str:
    """Cambia en cuanto alguien cambia una frase de entrenamiento."""
    h = hashlib.sha256()
    for archivo in (ETIQUETAS_ARCHIVO, TEMAS_ARCHIVO):
        h.update(archivo.read_bytes())
    return h.hexdigest()[:16]


def entrenar(etiquetas: list[dict], temas: list[dict]) -> tuple[Clasificador, Clasificador]:
    return (
        Clasificador().entrenar((f["frase"], f["etiqueta"]) for f in etiquetas),
        Clasificador().entrenar((f["frase"], f["tema"]) for f in temas),
    )


def guardar(etiquetas: Clasificador, temas: Clasificador, archivo: Path = MODELO) -> dict:
    datos = {
        "version": 1,
        "entrenado": dt.datetime.now().isoformat(timespec="seconds"),
        "huella": huella(),
        "frases": {"etiquetas": sum(etiquetas.frases.values()), "temas": sum(temas.frases.values())},
        "etiquetas": etiquetas.a_json(),
        "temas": temas.a_json(),
    }
    archivo.parent.mkdir(parents=True, exist_ok=True)
    archivo.write_text(json.dumps(datos, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return datos


def cargar_modelo(archivo: Path = MODELO) -> dict:
    if not archivo.exists():
        raise FileNotFoundError(f"No hay modelo en {archivo}. Corre: python entrenar.py")
    return json.loads(archivo.read_text(encoding="utf-8"))


def cargar() -> tuple[Clasificador, Clasificador, dict]:
    d = cargar_modelo()
    return Clasificador.de_json(d["etiquetas"]), Clasificador.de_json(d["temas"]), d
