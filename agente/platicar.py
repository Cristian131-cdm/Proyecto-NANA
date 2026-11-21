"""Platica con el agente de NANA en la terminal, para verlo funcionar en vivo.

    python platicar.py                      (Ollama qwen3:8b, con el propio de respaldo)
    python platicar.py --proveedores propio (solo el clasificador propio, sin modelo)

Escribe como si fueras Rosa. Debajo de cada respuesta sale qué decidió el
agente: de qué trata la frase, quién contestó y cuánto tardó.
Para salir: escribe "salir" o presiona Ctrl+C.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nana_agente.banco import DIA  # noqa: E402
from nana_agente.cadena import responder  # noqa: E402
from nana_agente.modelos import Peticion  # noqa: E402
from nana_agente.propio import ProveedorPropio  # noqa: E402
from nana_agente.proveedor import ConRespaldo, ProveedorOllama  # noqa: E402

GRIS, MORADO, VERDE, ROJO, FIN = "\033[90m", "\033[95m", "\033[92m", "\033[91m", "\033[0m"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stdin.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--proveedores", default="ollama,propio")
    ap.add_argument("--modelo", default="qwen3:8b")
    a = ap.parse_args()

    hay = {"ollama": lambda: ProveedorOllama(a.modelo), "propio": ProveedorPropio}
    prov = ConRespaldo([hay[n.strip()]() for n in a.proveedores.split(",")])

    print(f"{MORADO}NANA en vivo{FIN} · {prov.nombre}")
    print(f"{GRIS}El día de Rosa: " + " · ".join(f"{p.hora} {p.titulo}" for p in DIA) + FIN)
    if "ollama" in a.proveedores:
        print(f"{GRIS}Calentando el modelo (la primera vez puede tardar)…{FIN}")
        try:
            ProveedorOllama(a.modelo).conversar("Contesta en una palabra.",
                                                [{"role": "user", "content": "hola"}])
        except Exception as e:  # noqa: BLE001
            print(f"{ROJO}Ollama no contestó ({e}). Contestará el respaldo.{FIN}")
    print(f"{GRIS}Escribe como si fueras Rosa. «salir» para terminar.{FIN}\n")

    historial: list[dict] = []
    while True:
        try:
            frase = input("Rosa > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if frase.lower() in ("salir", "adios", "adiós"):
            break
        if not frase:
            continue
        r = responder(Peticion(frase, "Rosa", DIA, list(historial)), prov)
        print(f"{MORADO}NANA >{FIN} {r.texto}")
        quien = "reglas fijas (sin modelo)" if r.origen == "regla" else (r.proveedor or r.origen)
        extra = f" · propone anotar {r.propuesta.id}" if r.propuesta else ""
        extra += f" · abre: {r.accion}" if r.accion else ""
        extra += f" · {ROJO}guardián la cambió ({r.motivo}){GRIS}" if r.rechazada else ""
        color = VERDE if r.segundos <= 5 else ROJO
        print(f"{GRIS}       tema: {r.etiqueta} · contestó: {quien} · "
              f"{color}{r.segundos:.2f} s{GRIS}{extra}{FIN}\n")
        historial += [{"role": "user", "content": frase}, {"role": "assistant", "content": r.texto}]
        historial = historial[-6:]
    print(f"{MORADO}NANA >{FIN} ¡Hasta luego, Rosa!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
