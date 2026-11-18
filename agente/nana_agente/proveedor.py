"""La pieza intermedia: el agente nunca habla con un proveedor directamente.

Todo el agente pide dos cosas a esta interfaz: una respuesta con formato fijo
(`estructurado`) o una respuesta de plática, con o sin herramientas
(`conversar`). Cambiar de modelo, o tener uno de respaldo, es cambiar qué
objetos se le pasan a `ConRespaldo`; el resto del agente no se entera.
"""

from __future__ import annotations

import json
import queue
import threading
import time
import urllib.request
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Callable

from .reglas import normalizar


class ProveedorCaido(Exception):
    """El proveedor falló o contestó algo que no sirve."""


class SinRespuesta(ProveedorCaido):
    """Ningún proveedor contestó dentro del tiempo límite."""


@dataclass
class Llamada:
    nombre: str
    argumentos: dict


@dataclass
class Salida:
    texto: str = ""
    llamadas: list[Llamada] = field(default_factory=list)


@dataclass(frozen=True)
class Herramienta:
    nombre: str
    descripcion: str
    esquema: dict


class ProveedorModelo(ABC):
    nombre = "?"

    @abstractmethod
    def estructurado(self, sistema: str, texto: str, esquema: dict) -> dict:
        """Devuelve un dict que cumple `esquema` (JSON Schema)."""

    @abstractmethod
    def conversar(
        self,
        sistema: str,
        mensajes: list[dict],
        herramientas: tuple[Herramienta, ...] = (),
    ) -> Salida:
        """Devuelve texto y, si hay herramientas, las llamadas que el modelo propone."""


class ConRespaldo(ProveedorModelo):
    """Prueba los proveedores en orden y respeta un tiempo límite total.

    Si el principal tarda o falla, sigue con el respaldo. Si ninguno contesta
    a tiempo lanza SinRespuesta y la cadena dice la frase fija.
    """

    def __init__(self, proveedores: list[ProveedorModelo], limite: float = 5.0):
        if not proveedores:
            raise ValueError("Hace falta al menos un proveedor")
        self.proveedores = proveedores
        self.limite = limite
        self.nombre = " > ".join(p.nombre for p in proveedores)
        self.usado: str | None = None
        self.fallas: list[str] = []

    def _intentar(self, metodo: str, args: tuple, limite: float | None):
        fin = time.monotonic() + (self.limite if limite is None else limite)
        for i, p in enumerate(self.proveedores):
            resto = fin - time.monotonic()
            if resto <= 0:
                break
            # El tiempo se reparte: un principal colgado no se come el turno
            # del respaldo. El último se queda con todo lo que sobre.
            resto /= len(self.proveedores) - i
            caja: queue.Queue = queue.Queue(maxsize=1)

            def trabajo(p=p, caja=caja):
                try:
                    caja.put((True, getattr(p, metodo)(*args)))
                except Exception as e:  # noqa: BLE001 - cualquier falla cuenta
                    caja.put((False, e))

            # Hilo "daemon": si el proveedor se cuelga no detiene al servidor.
            threading.Thread(target=trabajo, daemon=True).start()
            try:
                bien, valor = caja.get(timeout=resto)
            except queue.Empty:
                self.fallas.append(f"{p.nombre}: sin respuesta a tiempo")
                continue
            if bien:
                self.usado = p.nombre
                return valor
            self.fallas.append(f"{p.nombre}: {valor}")
        raise SinRespuesta("; ".join(self.fallas[-len(self.proveedores):]) or "sin tiempo")

    def estructurado(self, sistema, texto, esquema, limite: float | None = None):
        return self._intentar("estructurado", (sistema, texto, esquema), limite)

    def conversar(self, sistema, mensajes, herramientas=(), limite: float | None = None):
        return self._intentar("conversar", (sistema, mensajes, herramientas), limite)


class ProveedorFalso(ProveedorModelo):
    """Para las pruebas: contesta lo que la prueba le diga y recuerda qué le pidieron."""

    def __init__(
        self,
        estructurados: Callable[[str, str, dict], dict] | dict | None = None,
        conversaciones: Callable[[str, list, tuple], Salida] | Salida | str | None = None,
        demora: float = 0.0,
        falla: bool = False,
        nombre: str = "falso",
    ):
        self._estructurados = estructurados
        self._conversaciones = conversaciones
        self.demora = demora
        self.falla = falla
        self.nombre = nombre
        self.pedidos: list[tuple] = []

    def _antes(self, pedido: tuple):
        self.pedidos.append(pedido)
        if self.demora:
            time.sleep(self.demora)
        if self.falla:
            raise ProveedorCaido(f"{self.nombre} está caído")

    def estructurado(self, sistema, texto, esquema):
        self._antes(("estructurado", sistema, texto))
        r = self._estructurados
        if callable(r):
            return r(sistema, texto, esquema)
        if r is None:
            raise ProveedorCaido("La prueba no esperaba una llamada estructurada")
        return r

    def conversar(self, sistema, mensajes, herramientas=()):
        self._antes(("conversar", sistema, mensajes))
        r = self._conversaciones
        if callable(r):
            return r(sistema, mensajes, herramientas)
        if r is None:
            raise ProveedorCaido("La prueba no esperaba una plática")
        return Salida(texto=r) if isinstance(r, str) else r


class ProveedorGuion(ProveedorModelo):
    """SIMULADO: no es un modelo. Contesta con palabras clave.

    Sirve para ensayar la demo y como último respaldo cuando no hay ningún
    modelo disponible. Hay que decir que es simulado cuando se use.
    """

    nombre = "guion (simulado)"

    _REGISTRO = ("ya tome", "ya me tome", "ya me la tome", "ya comi", "ya desayune",
                 "ya cene", "ya almorce", "ya camine", "ya hice", "ya sali a caminar")
    _FAMILIA = ("mi hija", "mi hijo", "mi nieta", "mi nieto", "mi familia", "llama")
    _COMPANIA = ("me siento", "sola", "solo", "triste", "aburrida", "aburrido",
                 "platica", "cuentame", "gracias", "buenos dias", "buenas", "hola",
                 "contenta", "contento", "feliz", "extrano", "como estas")

    def estructurado(self, sistema, texto, esquema):
        props = esquema.get("properties", {})
        if "aprobada" in props:
            return {"aprobada": True, "motivo": ""}
        t = f" {normalizar(texto)} "
        for etiqueta, frases in (("registro", self._REGISTRO),
                                 ("familia", self._FAMILIA),
                                 ("compania", self._COMPANIA)):
            if any(f" {f} " in t or f" {f}" in t for f in frases):
                return {"etiqueta": etiqueta}
        return {"etiqueta": "no_entendi"}

    def conversar(self, sistema, mensajes, herramientas=()):
        ultimo = mensajes[-1]["content"] if mensajes else ""
        if not herramientas:
            return Salida(texto="Aquí estoy contigo. Cuéntame más, te escucho.")
        try:
            datos = json.loads(ultimo)
        except ValueError:
            return Salida(texto="¿Me lo dices de otra forma?")
        t = normalizar(datos.get("frase", ""))
        pistas = {
            "medicina": ("pastilla", "medicina", "tome", "me la tome"),
            "comida": ("comi", "desayun", "cen", "almor"),
            "ejercicio": ("camin", "ejercicio"),
        }
        for p in datos.get("pendientes", []):
            if normalizar(p["titulo"]) in t or any(
                k in t for k in pistas.get(p["tipo"], ())
            ):
                return Salida(llamadas=[Llamada("proponer_registro", {"id": p["id"]})])
        return Salida(texto="No encontré eso en tu lista de hoy.")


class ProveedorOllama(ProveedorModelo):
    """Modelo abierto corriendo en una máquina propia (http://localhost:11434).

    SIN PROBAR: Ollama no estaba instalado cuando se escribió. Antes de usarlo
    hay que correr el banco de frases contra él.
    """

    def __init__(self, modelo: str = "llama3.2", url: str = "http://localhost:11434"):
        self.modelo = modelo
        self.url = url.rstrip("/")
        self.nombre = f"ollama:{modelo}"

    def _chat(self, cuerpo: dict) -> dict:
        cuerpo = {"model": self.modelo, "stream": False, **cuerpo}
        pedido = urllib.request.Request(
            f"{self.url}/api/chat",
            data=json.dumps(cuerpo).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(pedido, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))["message"]
        except Exception as e:  # noqa: BLE001
            raise ProveedorCaido(f"Ollama no contestó: {e}") from e

    def estructurado(self, sistema, texto, esquema):
        m = self._chat({
            "messages": [{"role": "system", "content": sistema},
                         {"role": "user", "content": texto}],
            "format": esquema,
        })
        try:
            return json.loads(m.get("content", ""))
        except ValueError as e:
            raise ProveedorCaido("Ollama no devolvió JSON") from e

    def conversar(self, sistema, mensajes, herramientas=()):
        cuerpo: dict = {"messages": [{"role": "system", "content": sistema}, *mensajes]}
        if herramientas:
            cuerpo["tools"] = [
                {"type": "function",
                 "function": {"name": h.nombre, "description": h.descripcion,
                              "parameters": h.esquema}}
                for h in herramientas
            ]
        m = self._chat(cuerpo)
        llamadas = []
        for c in m.get("tool_calls") or []:
            f = c.get("function", {})
            args = f.get("arguments") or {}
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except ValueError:
                    args = {}
            llamadas.append(Llamada(f.get("name", ""), args))
        return Salida(texto=m.get("content", "") or "", llamadas=llamadas)
