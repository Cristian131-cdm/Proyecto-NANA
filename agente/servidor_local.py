"""Entrada local del agente, SOLO para desarrollo y la demo.

    python agente/servidor_local.py

Variables de entorno:
    NANA_PROVEEDORES  lista en orden, separada por comas: ollama,guion  (por defecto: guion)
    NANA_OLLAMA       modelo de Ollama (por defecto: llama3.2)
    NANA_CLAVE_DEMO   si se pone, la app debe mandarla en el encabezado X-Nana-Demo
    NANA_PUERTO       por defecto 8787

En producción la entrada será una Cloud Function que verifica la sesión de
Firebase; este servidor no la verifica y no debe quedar abierto a internet.
"""

import json
import os
import sys
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nana_agente import frases_fijas as fijas  # noqa: E402
from nana_agente.cadena import responder  # noqa: E402
from nana_agente.modelos import Peticion, Resultado  # noqa: E402
from nana_agente.proveedor import ConRespaldo, ProveedorGuion, ProveedorOllama  # noqa: E402

TOPE_DIARIO = 40
TOPE_CUERPO = 20_000


def armar_proveedor() -> ConRespaldo:
    nombres = [n.strip() for n in os.environ.get("NANA_PROVEEDORES", "guion").split(",") if n.strip()]
    disponibles = {
        "guion": ProveedorGuion,
        "ollama": lambda: ProveedorOllama(os.environ.get("NANA_OLLAMA", "llama3.2")),
    }
    desconocidos = [n for n in nombres if n not in disponibles]
    if desconocidos:
        raise SystemExit(f"Proveedor desconocido: {', '.join(desconocidos)}")
    return ConRespaldo([disponibles[n]() for n in nombres])


class Tope:
    """Turnos por persona al día, en memoria."""

    def __init__(self, maximo: int = TOPE_DIARIO):
        self.maximo = maximo
        self._dia = date.today()
        self._cuenta: dict[str, int] = {}

    def permite(self, quien: str) -> bool:
        if date.today() != self._dia:
            self._dia, self._cuenta = date.today(), {}
        self._cuenta[quien] = self._cuenta.get(quien, 0) + 1
        return self._cuenta[quien] <= self.maximo


def crear_manejador(proveedor: ConRespaldo, clave: str, tope: Tope):
    class Manejador(BaseHTTPRequestHandler):
        def _json(self, codigo: int, cuerpo: dict):
            datos = json.dumps(cuerpo, ensure_ascii=False).encode("utf-8")
            self.send_response(codigo)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(datos)))
            self.end_headers()
            self.wfile.write(datos)

        def do_GET(self):  # noqa: N802
            if self.path == "/salud":
                self._json(200, {"ok": True, "proveedores": proveedor.nombre})
            else:
                self._json(404, {"error": "no existe"})

        def do_POST(self):  # noqa: N802
            if self.path != "/agente":
                return self._json(404, {"error": "no existe"})
            if clave and self.headers.get("X-Nana-Demo") != clave:
                return self._json(401, {"error": "falta la clave de la demo"})
            largo = int(self.headers.get("Content-Length") or 0)
            if largo <= 0 or largo > TOPE_CUERPO:
                return self._json(400, {"error": "petición vacía o muy grande"})
            try:
                cuerpo = json.loads(self.rfile.read(largo).decode("utf-8"))
                pet = Peticion.de_json(cuerpo)
            except (ValueError, KeyError, TypeError, AttributeError):
                return self._json(400, {"error": "la petición no es JSON válido"})
            quien = str(cuerpo.get("quien") or self.client_address[0])[:60]
            if not tope.permite(quien):
                return self._json(200, Resultado("no_entendi", fijas.TOPE_DIARIO, "regla").a_json())
            r = responder(pet, proveedor)
            # En la terminal solo va la etiqueta, no lo que dijo la persona.
            print(f"  {r.etiqueta:<16} {r.origen:<14} {r.proveedor or '-':<20} {r.segundos:.2f} s"
                  + (f"  RECHAZADA ({r.motivo})" if r.rechazada else ""))
            self._json(200, r.a_json())

        def log_message(self, *_):  # silencio: no se imprime cada petición
            pass

    return Manejador


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    proveedor = armar_proveedor()
    puerto = int(os.environ.get("NANA_PUERTO", "8787"))
    clave = os.environ.get("NANA_CLAVE_DEMO", "")
    servidor = ThreadingHTTPServer(("0.0.0.0", puerto), crear_manejador(proveedor, clave, Tope()))
    print(f"Agente de NANA en http://localhost:{puerto}  ·  proveedores: {proveedor.nombre}")
    if not clave:
        print("AVISO: sin NANA_CLAVE_DEMO cualquiera en tu red puede llamarlo.")
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nAgente detenido.")


if __name__ == "__main__":
    main()
