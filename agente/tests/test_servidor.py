"""El servidor local: orden de proveedores, calentar Ollama y las rutas HTTP."""

import json
import threading
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

import pytest

import servidor_local as sl
from nana_agente import proveedor as prov_mod
from nana_agente.propio import ProveedorPropio
from nana_agente.proveedor import ConRespaldo, ProveedorOllama


def test_por_defecto_qwen_primero_y_el_propio_de_respaldo(monkeypatch):
    monkeypatch.delenv("NANA_PROVEEDORES", raising=False)
    monkeypatch.delenv("NANA_OLLAMA", raising=False)
    p = sl.armar_proveedor()
    assert p.nombre == "ollama:qwen3:8b > propio"


def test_se_puede_elegir_solo_el_propio(monkeypatch):
    monkeypatch.setenv("NANA_PROVEEDORES", "propio")
    assert sl.armar_proveedor().nombre == "propio"


def test_proveedor_desconocido_detiene_el_arranque(monkeypatch):
    monkeypatch.setenv("NANA_PROVEEDORES", "ollama,chatgpt")
    with pytest.raises(SystemExit):
        sl.armar_proveedor()


def test_calentar_sin_ollama_avisa_pero_no_truena(monkeypatch):
    def apagado(*_a, **_k):
        raise urllib.error.URLError("conexión rechazada")

    monkeypatch.setattr(prov_mod.urllib.request, "urlopen", apagado)
    lineas = sl.calentar(ConRespaldo([ProveedorOllama("qwen3:8b"), ProveedorPropio()]))
    assert len(lineas) == 1
    assert lineas[0].startswith("AVISO: ollama:qwen3:8b no contestó")


def test_calentar_con_ollama(monkeypatch):
    class R:
        def read(self):
            return json.dumps({"message": {"content": "hola"}}).encode()

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    monkeypatch.setattr(prov_mod.urllib.request, "urlopen", lambda *a, **k: R())
    lineas = sl.calentar(ConRespaldo([ProveedorOllama("qwen3:8b")]))
    assert lineas[0].startswith("ollama:qwen3:8b listo")


def test_ips_locales_sin_127():
    assert all(not ip.startswith("127.") for ip in sl.ips_locales())


@pytest.fixture
def servidor():
    """Servidor de verdad en un puerto libre, solo con el propio (sin Ollama)."""
    def arrancar(clave=""):
        s = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            sl.crear_manejador(ConRespaldo([ProveedorPropio()]), clave, sl.Tope()),
        )
        threading.Thread(target=s.serve_forever, daemon=True).start()
        arrancados.append(s)
        return f"http://127.0.0.1:{s.server_address[1]}"

    arrancados: list = []
    yield arrancar
    for s in arrancados:
        s.shutdown()
        s.server_close()


def _post(url, cuerpo, clave=None):
    pedido = urllib.request.Request(
        f"{url}/agente",
        data=json.dumps(cuerpo).encode("utf-8"),
        headers={"Content-Type": "application/json", **({"X-Nana-Demo": clave} if clave else {})},
    )
    with urllib.request.urlopen(pedido, timeout=10) as r:
        return json.loads(r.read())


DIA = [{"id": "m1", "tipo": "medicina", "titulo": "Losartán", "hora": "8:00"}]


def test_salud(servidor):
    url = servidor()
    with urllib.request.urlopen(f"{url}/salud", timeout=10) as r:
        salud = json.loads(r.read())
    assert salud["ok"] is True
    assert salud["proveedores"] == "propio"


def test_agente_contesta_mi_dia(servidor):
    r = _post(servidor(), {"texto": "¿Qué me toca hoy?", "nombre": "Rosa", "dia": DIA})
    assert r["etiqueta"] == "mi_dia"
    assert "Losartán" in r["texto"]


def test_agente_urgencia(servidor):
    r = _post(servidor(), {"texto": "Me caí y no me puedo levantar", "nombre": "Rosa"})
    assert r["etiqueta"] == "urgencia"
    assert r["accion"] == "abrir_ayuda"


def test_con_clave_rechaza_a_quien_no_la_trae(servidor):
    url = servidor(clave="nana123")
    with pytest.raises(urllib.error.HTTPError) as e:
        _post(url, {"texto": "hola"})
    assert e.value.code == 401
    assert _post(url, {"texto": "hola"}, clave="nana123")["etiqueta"]
