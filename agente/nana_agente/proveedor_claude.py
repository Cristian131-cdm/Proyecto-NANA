"""Claude (API de Anthropic) como proveedor de la pieza intermedia.

Decisión del equipo (2026-11-21): la API externa solo platica. La compañía y
«Pregúntale a NANA» la usan primero; clasificar, registrar y el guardián
siguen en la laptop (Ollama → propio). Por eso, de fábrica, este proveedor
rechaza al instante lo que no es plática y `ConRespaldo` pasa al siguiente.

La llave sale de ANTHROPIC_API_KEY (la pone Cris en su terminal; nunca va en
el repo). El paquete `anthropic` se importa aquí adentro para que el resto del
agente siga funcionando sin él.
"""

from __future__ import annotations

import json
import os

from .proveedor import Llamada, ProveedorCaido, ProveedorModelo, Salida

MODELO_CLAUDE = "claude-haiku-5-5"

# Usos posibles: "platica" = conversar sin herramientas (compañía, encargado);
# "herramientas" = conversar con herramientas (registro); "estructurado" =
# JSON con esquema (orquestador, guardián, receta).
USOS_PLATICA = frozenset({"platica"})
TODOS_LOS_USOS = frozenset({"platica", "herramientas", "estructurado"})


def hay_llave() -> bool:
    return bool(os.environ.get("ANTHROPIC_API_KEY", "").strip())


def _mensajes_validos(mensajes: list[dict]) -> list[dict]:
    """La API pide empezar con 'user' y alternar. El historial de la app puede
    empezar con lo que dijo NANA o traer dos seguidos del mismo lado."""
    limpios: list[dict] = []
    for m in mensajes:
        rol = m.get("role")
        texto = str(m.get("content") or "").strip()
        if rol not in ("user", "assistant") or not texto:
            continue
        if not limpios and rol == "assistant":
            continue
        if limpios and limpios[-1]["role"] == rol:
            limpios[-1]["content"] += "\n" + texto
        else:
            limpios.append({"role": rol, "content": texto})
    if not limpios or limpios[-1]["role"] != "user":
        raise ProveedorCaido("Claude: la plática no termina en algo de la persona")
    return limpios


class ProveedorClaude(ProveedorModelo):
    # Va por internet: se lleva el 60 % del tiempo que queda; el resto es para
    # Qwen y el clasificador propio.
    parte = 0.6

    def __init__(self, modelo: str = MODELO_CLAUDE, usos: frozenset[str] = USOS_PLATICA,
                 cliente=None, max_tokens: int = 400):
        self.modelo = modelo
        self.usos = usos
        self.max_tokens = max_tokens
        self.nombre = f"claude:{modelo}"
        self._cliente = cliente

    def _api(self):
        if self._cliente is None:
            if not hay_llave():
                raise ProveedorCaido("Claude: falta ANTHROPIC_API_KEY")
            try:
                import anthropic
            except ImportError as e:
                raise ProveedorCaido("Claude: falta el paquete anthropic (pip install --user anthropic)") from e
            # Sin reintentos: si tarda, contesta el respaldo dentro de los 5 s.
            self._cliente = anthropic.Anthropic(max_retries=0, timeout=8.0)
        return self._cliente

    def _crear(self, **kw):
        cliente = self._api()
        try:
            r = cliente.messages.create(
                model=self.modelo,
                max_tokens=self.max_tokens,
                # Frases cortas para una persona mayor: sin pensar y esfuerzo
                # bajo, que es lo más rápido.
                thinking={"type": "disabled"},
                output_config={"effort": "low", **kw.pop("output_config", {})},
                **kw,
            )
        except ProveedorCaido:
            raise
        except Exception as e:  # noqa: BLE001 - red, llave, límite de gasto…
            raise ProveedorCaido(f"Claude no contestó: {type(e).__name__}: {e}") from e
        if r.stop_reason == "refusal":
            raise ProveedorCaido("Claude se negó a contestar")
        return r

    def estructurado(self, sistema, texto, esquema):
        if "estructurado" not in self.usos:
            raise ProveedorCaido("Claude solo platica (esto se decide en la laptop)")
        r = self._crear(
            system=sistema,
            messages=[{"role": "user", "content": texto}],
            output_config={"format": {"type": "json_schema", "schema": esquema}},
        )
        bloque = next((b.text for b in r.content if b.type == "text"), "")
        try:
            return json.loads(bloque)
        except ValueError as e:
            raise ProveedorCaido("Claude no devolvió JSON") from e

    def conversar(self, sistema, mensajes, herramientas=()):
        if herramientas and "herramientas" not in self.usos:
            raise ProveedorCaido("Claude solo platica (registrar se decide en la laptop)")
        if not herramientas and "platica" not in self.usos:
            raise ProveedorCaido("Claude no tiene permitido platicar aquí")
        kw: dict = {"system": sistema, "messages": _mensajes_validos(mensajes)}
        if herramientas:
            kw["tools"] = [
                {"name": h.nombre, "description": h.descripcion, "input_schema": h.esquema}
                for h in herramientas
            ]
        r = self._crear(**kw)
        texto = "".join(b.text for b in r.content if b.type == "text").strip()
        llamadas = [Llamada(b.name, dict(b.input or {})) for b in r.content if b.type == "tool_use"]
        if not texto and not llamadas:
            raise ProveedorCaido("Claude contestó vacío")
        return Salida(texto=texto, llamadas=llamadas)
