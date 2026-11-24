"""Junta las plantillas de Excel que regresa el equipo y reentrena a NANA.

    python juntar_frases.py <carpeta>            (revisa y agrega)
    python juntar_frases.py <carpeta> --revisar  (solo revisa, no cambia nada)

Lee todos los NANA_frases_*.xlsx de la carpeta (los hace hacer_plantillas.py):
  «Frases» → banco/entrenamiento.jsonl   (para entrenar el clasificador)
  «Temas»  → banco/temas.jsonl           (temas de plática)
  «Prueba» → banco/frases.jsonl          (banco de PRUEBA: nunca se entrena con él)
Salta renglones vacíos y el de ejemplo; avisa de etiquetas inválidas, repetidas
y de frases que estén a la vez en entrenamiento y en prueba. Después reentrena y
corre el banco con el clasificador propio.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from openpyxl import load_workbook

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

from nana_agente import banco  # noqa: E402
from nana_agente import entrenamiento as ent  # noqa: E402
from nana_agente.frases_fijas import ETIQUETAS  # noqa: E402
from nana_agente.reglas import normalizar  # noqa: E402

HOJAS = {"Frases": "etiqueta", "Temas": "tema", "Prueba": "etiqueta"}


@dataclass
class Resultado:
    entrenamiento: list[dict] = field(default_factory=list)
    temas: list[dict] = field(default_factory=list)
    prueba: list[dict] = field(default_factory=list)
    avisos: list[str] = field(default_factory=list)
    por_autor: Counter = field(default_factory=Counter)


def leer_plantilla(archivo: Path) -> dict[str, list[dict]]:
    """Las frases escritas de cada hoja: [{frase, etiqueta|tema, autor, renglon}]."""
    wb = load_workbook(archivo, read_only=True, data_only=True)
    autor_archivo = archivo.stem.removeprefix("NANA_frases_")
    salida: dict[str, list[dict]] = {}
    for hoja, campo in HOJAS.items():
        filas = []
        if hoja in wb.sheetnames:
            for n, (num, valor, frase, _que, autor) in enumerate(
                wb[hoja].iter_rows(min_row=2, max_col=5, values_only=True), 2
            ):
                if str(num or "").strip().lower().startswith("ej"):
                    continue  # el renglón de ejemplo
                frase = " ".join(str(frase or "").split())
                if not frase:
                    continue
                filas.append({"frase": frase, campo: str(valor or "").strip(),
                              "autor": str(autor or autor_archivo).strip(), "renglon": n})
        salida[hoja] = filas
    wb.close()
    return salida


def juntar(carpeta: Path) -> Resultado:
    """Lee y revisa todo; no escribe nada."""
    r = Resultado()
    vistas: dict[str, str] = {}
    for x in ent.leer_etiquetas():
        vistas[normalizar(x["frase"])] = "entrenamiento.jsonl"
    for x in ent.leer_temas():
        vistas[normalizar(x["frase"])] = "temas.jsonl"
    for x in banco.leer():
        vistas[normalizar(x["frase"])] = "frases.jsonl (prueba)"

    for archivo in sorted(carpeta.glob("NANA_frases_*.xlsx")):
        if archivo.name.startswith("~$"):
            continue  # archivo temporal de Excel abierto
        for hoja, filas in leer_plantilla(archivo).items():
            campo = HOJAS[hoja]
            validas = ent.TEMAS if campo == "tema" else ETIQUETAS
            for f in filas:
                donde = f"{archivo.name} · {hoja} · renglón {f['renglon']}"
                if f[campo] not in validas:
                    r.avisos.append(f"{donde}: {campo} «{f[campo]}» no existe; la salté.")
                    continue
                if hoja == "Prueba" and f[campo] not in banco.GRUPOS:
                    r.avisos.append(f"{donde}: «{f[campo]}» no tiene grupo en el banco de prueba; la salté.")
                    continue
                clave = normalizar(f["frase"])
                if clave in vistas:
                    r.avisos.append(f"{donde}: «{f['frase']}» ya está en {vistas[clave]}; la salté.")
                    continue
                vistas[clave] = f"{archivo.name} · {hoja}"
                fila = {"frase": f["frase"], campo: f[campo], "autor": f["autor"]}
                if hoja == "Frases":
                    r.entrenamiento.append(fila)
                elif hoja == "Temas":
                    r.temas.append(fila)
                else:
                    r.prueba.append({"grupo": f[campo], "frase": f["frase"],
                                     "esperada": [f[campo]], "autor": f["autor"]})
                r.por_autor[f["autor"]] += 1
    return r


def _agregar(destino: Path, filas: list[dict]):
    if not filas:
        return
    texto = destino.read_text(encoding="utf-8")
    with destino.open("a", encoding="utf-8", newline="\n") as f:
        if texto and not texto.endswith("\n"):
            f.write("\n")
        for fila in filas:
            f.write(json.dumps(fila, ensure_ascii=False) + "\n")


def escribir(r: Resultado):
    _agregar(ent.ETIQUETAS_ARCHIVO, r.entrenamiento)
    _agregar(ent.TEMAS_ARCHIVO, r.temas)
    _agregar(banco.ARCHIVO, r.prueba)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("carpeta", type=Path)
    ap.add_argument("--revisar", action="store_true", help="solo revisa, no cambia nada")
    a = ap.parse_args()

    r = juntar(a.carpeta)
    print(f"Entrenamiento: {len(r.entrenamiento)} · Temas: {len(r.temas)} · Prueba: {len(r.prueba)}")
    for autor, n in r.por_autor.most_common():
        print(f"  {autor:<10} {n} frases")
    for aviso in r.avisos:
        print("  !!", aviso)
    if a.revisar:
        print("\n(Solo revisé: no cambié nada.)")
        return 0
    if not (r.entrenamiento or r.temas or r.prueba):
        print("No hay frases nuevas.")
        return 0
    escribir(r)
    print("\nAgregadas. Reentreno y corro el banco con el clasificador propio…\n")
    subprocess.run([sys.executable, str(AQUI / "entrenar.py")], check=False)
    subprocess.run([sys.executable, str(AQUI / "correr_banco.py")], check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
