"""ProveedorOllama: lo que manda a Ollama, sin necesitar Ollama prendido."""

import json

from nana_agente import proveedor
from nana_agente.proveedor import ProveedorOllama


class _Respuesta:
    def __init__(self, datos: dict):
        self._datos = json.dumps(datos).encode("utf-8")

    def read(self):
        return self._datos

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def _espiar(monkeypatch, mensaje: dict) -> list:
    pedidos = []

    def falso_urlopen(pedido, timeout=None):
        pedidos.append((pedido.full_url, json.loads(pedido.data.decode("utf-8"))))
        return _Respuesta({"message": mensaje})

    monkeypatch.setattr(proveedor.urllib.request, "urlopen", falso_urlopen)
    return pedidos


def test_apaga_el_modo_pensar_y_no_se_descarga(monkeypatch):
    pedidos = _espiar(monkeypatch, {"content": "Hola, Rosa."})
    ProveedorOllama("qwen3:8b").conversar("sé amable", [{"role": "user", "content": "hola"}])
    _, cuerpo = pedidos[0]
    assert cuerpo["think"] is False
    assert cuerpo["keep_alive"] == "30m"
    assert cuerpo["model"] == "qwen3:8b"


def test_usa_127_0_0_1_y_no_localhost(monkeypatch):
    # En Windows "localhost" prueba IPv6 primero y cuesta ~2 s por llamada.
    pedidos = _espiar(monkeypatch, {"content": "{\"etiqueta\": \"compania\"}"})
    r = ProveedorOllama("qwen3:8b").estructurado("clasifica", "hola", {"type": "object"})
    url, _ = pedidos[0]
    assert url.startswith("http://127.0.0.1:11434/")
    assert r == {"etiqueta": "compania"}
