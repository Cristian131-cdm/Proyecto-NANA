"""ProveedorClaude con un cliente falso: no gasta saldo ni necesita internet."""

import sys
import time
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from nana_agente.proveedor import ConRespaldo, Herramienta, ProveedorCaido, ProveedorFalso  # noqa: E402
from nana_agente.proveedor_claude import (  # noqa: E402
    TODOS_LOS_USOS, ProveedorClaude, _mensajes_validos,
)


def texto(t):
    return SimpleNamespace(type="text", text=t)


class ClienteFalso:
    def __init__(self, contenido=(), stop="end_turn", error=None, tarda=0.0):
        self.contenido = list(contenido)
        self.stop = stop
        self.error = error
        self.tarda = tarda
        self.pedidos = []
        self.messages = self

    def create(self, **kw):
        self.pedidos.append(kw)
        if self.tarda:
            time.sleep(self.tarda)
        if self.error:
            raise self.error
        return SimpleNamespace(content=self.contenido, stop_reason=self.stop)


def test_platica_usa_haiku_sin_pensar_y_esfuerzo_bajo():
    c = ClienteFalso([texto("¡Qué gusto oírte, Rosa!")])
    s = ProveedorClaude(cliente=c).conversar("Eres NANA.", [{"role": "user", "content": "hola"}])
    assert s.texto == "¡Qué gusto oírte, Rosa!"
    p = c.pedidos[0]
    assert p["model"] == "claude-haiku-5-5"
    assert p["thinking"] == {"type": "disabled"}
    assert p["output_config"]["effort"] == "low"
    assert p["system"] == "Eres NANA."
    assert "temperature" not in p


def test_de_fabrica_no_clasifica_ni_registra():
    c = ClienteFalso([texto("x")])
    claude = ProveedorClaude(cliente=c)
    with pytest.raises(ProveedorCaido):
        claude.estructurado("s", "t", {"type": "object"})
    with pytest.raises(ProveedorCaido):
        claude.conversar("s", [{"role": "user", "content": "ya"}], (Herramienta("marcar", "d", {"type": "object"}),))
    assert c.pedidos == []  # ni siquiera llamó a la API


def test_con_respaldo_lo_que_no_es_platica_pasa_a_la_laptop_al_instante():
    local = ProveedorFalso(estructurados={"etiqueta": "registro"})
    cadena = ConRespaldo([ProveedorClaude(cliente=ClienteFalso()), local], limite=5.0)
    inicio = time.monotonic()
    assert cadena.estructurado("s", "ya me la tomé", {"type": "object"}) == {"etiqueta": "registro"}
    assert time.monotonic() - inicio < 0.5
    assert cadena.usado == local.nombre


def test_si_claude_falla_contesta_el_respaldo():
    local = ProveedorFalso(conversaciones="Aquí estoy contigo.")
    caido = ClienteFalso(error=ConnectionError("sin internet"))
    cadena = ConRespaldo([ProveedorClaude(cliente=caido), local], limite=5.0)
    s = cadena.conversar("s", [{"role": "user", "content": "me siento sola"}])
    assert s.texto == "Aquí estoy contigo."
    assert any("sin internet" in f for f in cadena.fallas)


def test_claude_lento_no_se_come_todo_el_tiempo():
    local = ProveedorFalso(conversaciones="Respaldo.")
    lento = ClienteFalso([texto("tarde")], tarda=3.0)
    cadena = ConRespaldo([ProveedorClaude(cliente=lento), local], limite=1.0)
    inicio = time.monotonic()
    assert cadena.conversar("s", [{"role": "user", "content": "hola"}]).texto == "Respaldo."
    assert time.monotonic() - inicio < 1.0


def test_negarse_cuenta_como_falla():
    c = ClienteFalso([texto("")], stop="refusal")
    with pytest.raises(ProveedorCaido):
        ProveedorClaude(cliente=c).conversar("s", [{"role": "user", "content": "hola"}])


def test_sin_llave_falla_sin_romper(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    with pytest.raises(ProveedorCaido, match="ANTHROPIC_API_KEY"):
        ProveedorClaude().conversar("s", [{"role": "user", "content": "hola"}])


def test_estructurado_si_se_permite():
    c = ClienteFalso([texto('{"medicinas": []}')])
    r = ProveedorClaude(cliente=c, usos=TODOS_LOS_USOS).estructurado("s", "receta", {"type": "object"})
    assert r == {"medicinas": []}
    assert c.pedidos[0]["output_config"]["format"]["type"] == "json_schema"


def test_herramientas_si_se_permiten():
    c = ClienteFalso([SimpleNamespace(type="tool_use", name="marcar", input={"id": "m1"})])
    s = ProveedorClaude(cliente=c, usos=TODOS_LOS_USOS).conversar(
        "s", [{"role": "user", "content": "ya"}], (Herramienta("marcar", "d", {"type": "object"}),))
    assert s.llamadas[0].nombre == "marcar" and s.llamadas[0].argumentos == {"id": "m1"}


def test_historial_se_acomoda_para_la_api():
    m = _mensajes_validos([
        {"role": "assistant", "content": "Hola, soy NANA"},
        {"role": "user", "content": "hola"},
        {"role": "user", "content": "¿cómo estás?"},
        {"role": "assistant", "content": "Bien"},
        {"role": "user", "content": "qué bueno"},
    ])
    assert [x["role"] for x in m] == ["user", "assistant", "user"]
    assert m[0]["content"] == "hola\n¿cómo estás?"


def test_la_cadena_dice_quien_escribio_la_respuesta_no_quien_la_reviso():
    # Claude platica; Qwen clasifica y el guardián revisa después. El campo
    # `proveedor` debe decir Claude: antes decía el último que habló (el juez).
    from nana_agente.banco import DIA
    from nana_agente.cadena import responder
    from nana_agente.modelos import Peticion

    def qwen_estructurado(sistema, texto, esquema):
        if "aprobada" in esquema["properties"]:
            return {"aprobada": True, "motivo": ""}
        return {"etiqueta": "compania"}

    claude = ProveedorFalso(conversaciones="Qué gusto platicar contigo, Rosa.", nombre="claude")
    qwen = ProveedorFalso(estructurados=qwen_estructurado, nombre="qwen")
    r = responder(Peticion("Vieras qué aburrida está la tarde", "Rosa", DIA), ConRespaldo([claude, qwen]))
    assert r.texto == "Qué gusto platicar contigo, Rosa."
    assert r.proveedor == "claude"


def test_las_instrucciones_no_confunden_a_nana_con_la_persona():
    # Con "Se llama Rosa." a secas, Claude y Qwen contestaban «Hola, soy Rosa».
    from nana_agente.compania import _sistema

    s = _sistema("Rosa")
    assert "Tú te llamas NANA" in s
    assert "La persona con quien platicas se llama Rosa" in s
    assert ".Si " not in s and ".No " not in s  # frases pegadas
