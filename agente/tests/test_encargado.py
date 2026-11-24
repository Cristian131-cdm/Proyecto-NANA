"""«Pregúntale a NANA» del encargado: solo lectura, solo con el resumen."""

import json
import threading
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import servidor_local as sl
from nana_agente import encargado
from nana_agente.propio import ProveedorPropio
from nana_agente.proveedor import ConRespaldo, ProveedorFalso, Salida

DATOS = json.loads(
    (Path(__file__).resolve().parent.parent / "banco" / "encargado_datos.json").read_text(encoding="utf-8")
)
APRUEBA = {"aprobada": True, "motivo": ""}


def modelo(texto="El martes y el jueves no se marcó el Losartán.", juez=APRUEBA, **kw):
    return ProveedorFalso(lambda _s, _t, _e: juez, texto, **kw)


def test_contesta_con_el_resumen():
    m = modelo()
    r = encargado.contestar("¿Qué días no se tomó el Losartán?", "Rosa", DATOS, (), m)
    assert r.etiqueta == "encargado"
    assert r.texto == "El martes y el jueves no se marcó el Losartán."
    # El modelo recibió el resumen y la pregunta; nada más del expediente.
    _, sistema, mensajes = m.pedidos[0]
    assert "Rosa" in sistema
    assert "martes 18" in mensajes[-1]["content"]
    assert "PREGUNTA: ¿Qué días no se tomó el Losartán?" in mensajes[-1]["content"]


def test_la_pregunta_medica_no_llega_al_modelo():
    m = modelo()
    for p in ["¿Le subo la dosis del Losartán?", "¿Qué tiene mi mamá, será la presión?",
              "¿Le doy algo para el dolor?"]:
        r = encargado.contestar(p, "Rosa", DATOS, (), m)
        assert r.etiqueta == "pregunta_medica", p
        assert "médico" in r.texto
    assert m.pedidos == []


def test_el_guardian_detiene_un_consejo():
    m = modelo("Puedes darle media pastilla más en la noche.", juez={"aprobada": False, "motivo": "dosis"})
    r = encargado.contestar("¿Qué hago si se siente mareada?", "Rosa", DATOS, (), m)
    assert r.rechazada
    assert r.texto == encargado.SEGURA


def test_con_solo_el_clasificador_propio_dice_que_no_sabe():
    r = encargado.contestar("¿Comió bien?", "Rosa", DATOS, (), ConRespaldo([ProveedorPropio()]))
    assert r.origen == "sin_respuesta"
    assert r.texto == encargado.SIN_DATO


def test_si_el_modelo_tarda_dice_que_no_sabe():
    m = modelo(demora=2)
    r = encargado.contestar("¿Comió bien?", "Rosa", DATOS, (), ConRespaldo([m], limite=0.3), limite=0.3)
    assert r.origen == "sin_respuesta"


def test_respuesta_larga_se_recorta_en_un_punto():
    largo = "El martes no se marcó. " * 40
    r = encargado.contestar("¿Cómo le fue?", "Rosa", DATOS, (), modelo(largo))
    assert len(r.texto) <= encargado.TOPE_RESPUESTA
    assert r.texto.endswith(".")


def test_la_ruta_http():
    s = ThreadingHTTPServer(("127.0.0.1", 0), sl.crear_manejador(ConRespaldo([modelo()]), "", sl.Tope()))
    threading.Thread(target=s.serve_forever, daemon=True).start()
    try:
        cuerpo = json.dumps({"pregunta": "¿Qué días no se tomó el Losartán?", "nombre": "Rosa",
                             "datos": DATOS, "historial": []}).encode("utf-8")
        pedido = urllib.request.Request(
            f"http://127.0.0.1:{s.server_address[1]}/encargado", data=cuerpo,
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(pedido, timeout=10) as r:
            j = json.loads(r.read())
        assert j["etiqueta"] == "encargado"
        assert "jueves" in j["texto"]
    finally:
        s.shutdown()
        s.server_close()


def test_banco_del_encargado_bien_formado():
    import correr_banco
    casos = correr_banco.leer_banco_encargado()
    assert len(casos) >= 12
    assert sum(1 for c in casos if c.get("medica")) >= 2
