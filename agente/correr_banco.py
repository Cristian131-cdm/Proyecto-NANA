"""Corre el banco de frases contra un proveedor y dice cuántas pasan.

    python agente/correr_banco.py --proveedor guion
    python agente/correr_banco.py --proveedor ollama --modelo llama3.2
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nana_agente import banco  # noqa: E402
from nana_agente.proveedor import ProveedorGuion, ProveedorOllama  # noqa: E402


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--proveedor", choices=["guion", "ollama"], default="guion")
    ap.add_argument("--modelo", default="llama3.2")
    ap.add_argument("--limite", type=float, default=5.0)
    a = ap.parse_args()

    proveedor = ProveedorGuion() if a.proveedor == "guion" else ProveedorOllama(a.modelo)
    casos = banco.leer()
    errores = banco.validar(casos)
    if errores:
        print("El banco tiene errores:\n  " + "\n  ".join(errores))
        return 2
    print(f"Proveedor: {proveedor.nombre} · {len(casos)} frases · límite {a.limite} s\n")
    filas = banco.correr(proveedor, casos, a.limite)
    print(banco.resumen(filas))
    return 0 if all(f.pasa for f in filas) else 1


if __name__ == "__main__":
    raise SystemExit(main())
