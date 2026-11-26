"""Entrada local del agente, SOLO para desarrollo y la demo.

    python agente/servidor_local.py

Variables de entorno:
    NANA_PROVEEDORES  lista en orden, separada por comas  (por defecto: claude,ollama,propio
                      si hay ANTHROPIC_API_KEY; si no, ollama,propio)
                      claude = Haiku 5.5 por internet, solo para platicar
                      ollama = Qwen en esta laptop · propio = clasificador sin modelo
                      guion = simulado por palabras clave (solo para ensayar)
    NANA_OLLAMA       modelo de Ollama (por defecto: qwen3:8b)
    NANA_CLAVE_DEMO   si se pone, la app debe mandarla en el encabezado X-Nana-Demo
    NANA_PUERTO       por defecto 8787

En producción la entrada será una Cloud Function que verifica la sesión de
Firebase; este servidor no la verifica y no debe quedar abierto a internet.
"""

import json
import os
import socket
import sys
import time
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nana_agente import encargado, receta  # noqa: E402
from nana_agente import frases_fijas as fijas  # noqa: E402
from nana_agente.cadena import responder  # noqa: E402
from nana_agente.modelos import Peticion, Resultado  # noqa: E402
from nana_agente.propio import ProveedorPropio  # noqa: E402
from nana_agente.proveedor import (  # noqa: E402
    ConRespaldo, ProveedorCaido, ProveedorGuion, ProveedorOllama,
)
from nana_agente.proveedor_claude import TODOS_LOS_USOS, ProveedorClaude, hay_llave  # noqa: E402

TOPE_DIARIO = 40
TOPE_CUERPO = 20_000


PROVEEDORES = "ollama,propio"
PROVEEDORES_CON_LLAVE = "claude,ollama,propio"
MODELO_OLLAMA = "qwen3:8b"


def armar_proveedor() -> ConRespaldo:
    defecto = PROVEEDORES_CON_LLAVE if hay_llave() else PROVEEDORES
    nombres = [n.strip() for n in os.environ.get("NANA_PROVEEDORES", defecto).split(",") if n.strip()]
    disponibles = {
        "claude": ProveedorClaude,
        "propio": ProveedorPropio,
        "guion": ProveedorGuion,
        "ollama": lambda: ProveedorOllama(os.environ.get("NANA_OLLAMA", MODELO_OLLAMA)),
    }
    desconocidos = [n for n in nombres if n not in disponibles]
    if desconocidos:
        raise SystemExit(f"Proveedor desconocido: {', '.join(desconocidos)}")
    return ConRespaldo([disponibles[n]() for n in nombres])


def proveedor_receta(proveedor: ConRespaldo) -> ConRespaldo | None:
    """Para leer recetas: los mismos modelos, pero Claude sí puede devolver
    JSON (copiar datos de una receta no es platicar). Sin propio ni guion: si
    no hay modelo, receta.leer usa sus patrones."""
    modelos = []
    for p in proveedor.proveedores:
        if isinstance(p, ProveedorClaude):
            modelos.append(ProveedorClaude(p.modelo, usos=TODOS_LOS_USOS, max_tokens=1500))
        elif isinstance(p, ProveedorOllama):
            modelos.append(p)
    return ConRespaldo(modelos, limite=15.0) if modelos else None


def calentar(proveedor: ConRespaldo) -> list[str]:
    """Carga en la GPU los modelos de Ollama para que la primera frase no tarde.

    Regresa una línea por modelo para imprimirla. Si Ollama no contesta no
    detiene nada: contestará el siguiente proveedor de la lista.
    """
    lineas = []
    for p in proveedor.proveedores:
        if not isinstance(p, ProveedorOllama):
            continue
        inicio = time.monotonic()
        try:
            p.conversar("Contesta en una palabra.", [{"role": "user", "content": "hola"}])
            lineas.append(f"{p.nombre} listo ({time.monotonic() - inicio:.1f} s)")
        except ProveedorCaido as e:
            lineas.append(f"AVISO: {p.nombre} no contestó ({e}). ¿Está abierto Ollama? "
                          "Mientras tanto contesta el respaldo.")
    return lineas


def ips_locales() -> list[str]:
    """Las IP de esta laptop en la red (la que el celular debe usar en la Fase 4)."""
    ips: list[str] = []
    try:
        # No manda nada: solo pregunta por qué tarjeta de red saldría.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            ips.append(s.getsockname()[0])
    except OSError:
        pass
    try:
        for ip in socket.gethostbyname_ex(socket.gethostname())[2]:
            if ip not in ips:
                ips.append(ip)
    except OSError:
        pass
    # 127.x es la misma laptop y 169.254.x es una tarjeta sin red: no sirven.
    return [ip for ip in ips if not ip.startswith(("127.", "169.254."))]


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
    lector_receta = proveedor_receta(proveedor)

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
                salud = {
                    "ok": True,
                    "proveedores": proveedor.nombre,
                    # Para el botón «Probar» de la app: dice si se pide clave y
                    # si la que mandó coincide, nunca cuál es.
                    "pide_clave": bool(clave),
                    "clave_ok": not clave or self.headers.get("X-Nana-Demo") == clave,
                }
                for p in proveedor.proveedores:
                    if isinstance(p, ProveedorOllama):
                        salud["ollama"] = p.modelo
                    if isinstance(p, ProveedorClaude):
                        salud["claude"] = p.modelo
                    if isinstance(p, ProveedorPropio):
                        # Qué modelo está contestando: se ve en la demo.
                        salud["modelo"] = {k: p.info[k] for k in ("entrenado", "huella", "frases")}
                self._json(200, salud)
            else:
                self._json(404, {"error": "no existe"})

        def do_POST(self):  # noqa: N802
            if self.path not in ("/agente", "/encargado", "/receta"):
                return self._json(404, {"error": "no existe"})
            largo = int(self.headers.get("Content-Length") or 0)
            if largo <= 0 or largo > TOPE_CUERPO:
                self.close_connection = True
                return self._json(400, {"error": "petición vacía o muy grande"})
            # Se lee antes de contestar cualquier error: si se responde sin
            # leer, Windows a veces corta la conexión (WinError 10053) y la
            # app no recibe ni el error.
            datos = self.rfile.read(largo)
            if clave and self.headers.get("X-Nana-Demo") != clave:
                return self._json(401, {"error": "falta la clave de la demo"})
            if self.path == "/receta":
                # Solo el texto que leyó el OCR del celular; la foto no sale de ahí.
                try:
                    cuerpo = json.loads(datos.decode("utf-8"))
                    texto = str(cuerpo.get("texto") or "")
                except (ValueError, AttributeError):
                    return self._json(400, {"error": "la petición no es JSON válido"})
                meds, quien = receta.leer(texto, lector_receta)
                print(f"  receta           {quien:<20} {len(meds)} medicinas")
                return self._json(200, {"medicinas": [m.a_json() for m in meds], "proveedor": quien})
            try:
                cuerpo = json.loads(datos.decode("utf-8"))
                if not isinstance(cuerpo, dict):
                    raise ValueError("no es un objeto")
                pet = Peticion.de_json(cuerpo)
            except (ValueError, KeyError, TypeError, AttributeError):
                return self._json(400, {"error": "la petición no es JSON válido"})
            quien = str(cuerpo.get("quien") or self.client_address[0])[:60]
            if not tope.permite(quien):
                return self._json(200, Resultado("no_entendi", fijas.TOPE_DIARIO, "regla").a_json())
            if self.path == "/encargado":
                # Solo lectura: pregunta + resumen que armó la app (sin
                # expediente). El historial usa el mismo filtro que /agente.
                d = cuerpo.get("datos")
                r = encargado.contestar(
                    str(cuerpo.get("pregunta") or cuerpo.get("texto") or ""),
                    pet.nombre,
                    d if isinstance(d, dict) else {},
                    pet.historial,
                    proveedor,
                )
            else:
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
    print(f"Agente de NANA · proveedores: {proveedor.nombre}")
    for linea in calentar(proveedor):
        print(f"  {linea}")
    print(f"\nEn esta laptop:  http://127.0.0.1:{puerto}/salud")
    ips = ips_locales()
    if ips:
        print(f"Desde el celular (misma red o hotspot):  http://{ips[0]}:{puerto}/salud")
        if len(ips) > 1:
            # Las otras suelen ser redes virtuales de Windows; sirven si el
            # celular está conectado al hotspot de la laptop (192.168.137.x).
            print("  Si no abre, prueba: " + ", ".join(ips[1:]))
    else:
        print("No encontré la IP de la laptop en la red. ¿Está conectada al Wi-Fi o al hotspot?")
    if not clave:
        print("\nAVISO: sin NANA_CLAVE_DEMO cualquiera en tu red puede llamarlo.")
    print("\nCtrl+C para detenerlo. Cada frase sale aquí (solo el tema, no lo que dijo):\n")
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nAgente detenido.")


if __name__ == "__main__":
    main()
