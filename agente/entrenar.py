"""Entrena el clasificador propio de NANA y lo guarda en modelo/nana.json.

    python entrenar.py                         revisa las frases, mide y entrena
    python entrenar.py --agregar frases.csv    suma las frases del equipo y entrena

El CSV del equipo (se puede llenar en Excel o Google Sheets y guardar como CSV
UTF-8) lleva las columnas  frase,etiqueta,autor  o  frase,tema,autor.
Ver banco/plantilla_frases_equipo.csv.
"""

import argparse
import csv
import json
import random
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nana_agente import banco, entrenamiento as ent  # noqa: E402
from nana_agente.clasificador import Clasificador  # noqa: E402


def agregar(archivo: Path) -> int:
    with archivo.open(encoding="utf-8-sig", newline="") as f:
        filas = [{k.strip().lower(): (v or "").strip() for k, v in r.items() if k} for r in csv.DictReader(f)]
    if not filas:
        print(f"{archivo} está vacío.")
        return 0
    campo = "etiqueta" if "etiqueta" in filas[0] else "tema" if "tema" in filas[0] else None
    if campo is None:
        raise SystemExit("El CSV necesita una columna 'etiqueta' o 'tema'.")
    destino = ent.ETIQUETAS_ARCHIVO if campo == "etiqueta" else ent.TEMAS_ARCHIVO
    with destino.open("a", encoding="utf-8", newline="\n") as f:
        n = 0
        for r in filas:
            if r.get("frase"):
                fila = {"frase": r["frase"], campo: r.get(campo, ""), "autor": r.get("autor") or archivo.stem}
                f.write(json.dumps(fila, ensure_ascii=False) + "\n")
                n += 1
    print(f"Agregué {n} frases a {destino.name}.")
    return n


def validacion_cruzada(filas: list[dict], campo: str, partes: int = 5) -> tuple[float, dict]:
    """Entrena con 4/5 de las frases y prueba con el 1/5 que no vio, 5 veces."""
    filas = filas[:]
    random.Random(7).shuffle(filas)
    bien, por = 0, Counter()
    total = Counter()
    for k in range(partes):
        prueba = filas[k::partes]
        resto = [f for i, f in enumerate(filas) if i % partes != k]
        c = Clasificador().entrenar((f["frase"], f[campo]) for f in resto)
        for f in prueba:
            total[f[campo]] += 1
            if c.predecir(f["frase"], umbral=0).etiqueta == f[campo]:
                bien += 1
                por[f[campo]] += 1
    return bien / max(len(filas), 1), {e: (por[e], total[e]) for e in sorted(total)}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--agregar", type=Path, nargs="*", default=[])
    a = ap.parse_args()
    for archivo in a.agregar:
        agregar(archivo)

    etiquetas, temas = ent.leer_etiquetas(), ent.leer_temas()
    errores = ent.validar(etiquetas, temas, banco.leer())
    if errores:
        print("Hay que corregir las frases antes de entrenar:\n  " + "\n  ".join(errores))
        return 2

    for nombre, filas, campo in (("Etiquetas", etiquetas, "etiqueta"), ("Temas de plática", temas, "tema")):
        exacto, por = validacion_cruzada(filas, campo)
        print(f"{nombre}: {len(filas)} frases · acierta {exacto:.0%} en frases que no vio (validación cruzada, 5 partes)")
        for e, (ok, n) in por.items():
            print(f"   {e:<16}{ok:>3}/{n:<3}")
    if len(etiquetas) < ent.META:
        print(f"\nAviso: el plan pide al menos {ent.META} frases de etiquetas; hay {len(etiquetas)}.")

    datos = ent.guardar(*ent.entrenar(etiquetas, temas))
    print(f"\nModelo guardado en {ent.MODELO.relative_to(ent.RAIZ)} · huella {datos['huella']} · {datos['entrenado']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
