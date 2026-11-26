import json
import time

import pytest

from nana_agente import banco, frases_fijas as fijas, guardian
from nana_agente.cadena import responder
from nana_agente.modelos import Pendiente, Peticion
from nana_agente.proveedor import (
    ConRespaldo, Llamada, ProveedorFalso, ProveedorGuion, Salida, SinRespuesta,
)
from nana_agente.reglas import normalizar, regla_fija

DIA = banco.DIA
UNA = (Pendiente("m1", "medicina", "Losartán", "8:00"), Pendiente("c1", "comida", "Desayuno"))
APRUEBA = {"aprobada": True, "motivo": ""}


def falso(etiqueta=None, platica=None, juez=APRUEBA, **kw):
    """Proveedor falso: clasifica `etiqueta`, platica `platica` y el juez dice `juez`."""
    def estructurado(_s, _t, esquema):
        return juez if "aprobada" in esquema["properties"] else {"etiqueta": etiqueta}
    return ProveedorFalso(estructurado, platica, **kw)


# ---------- Paso 1: banco ----------

def test_banco_bien_formado():
    casos = banco.leer()
    assert banco.validar(casos) == []
    assert len(casos) >= 30


# ---------- Paso 2: proveedor con respaldo ----------

def test_principal_lento_usa_el_respaldo():
    lento = falso("compania", demora=3, nombre="principal")
    respaldo = falso("compania", nombre="respaldo")
    prov = ConRespaldo([lento, respaldo], limite=1.0)
    inicio = time.monotonic()
    # Al principal le toca la mitad del tiempo; después contesta el respaldo.
    assert prov.estructurado("s", "hola", {"properties": {"etiqueta": {}}}) == {"etiqueta": "compania"}
    assert prov.usado == "respaldo"
    assert time.monotonic() - inicio < 1.0


def test_principal_caido_usa_el_respaldo():
    prov = ConRespaldo([falso(falla=True, nombre="principal"), falso("compania", nombre="respaldo")])
    assert prov.estructurado("s", "hola", {"properties": {"etiqueta": {}}}) == {"etiqueta": "compania"}
    assert prov.usado == "respaldo"
    assert "principal" in prov.fallas[0]


def test_todos_caidos_frase_fija_a_tiempo():
    prov = ConRespaldo([falso(demora=10, nombre="a"), falso(falla=True, nombre="b")])
    inicio = time.monotonic()
    r = responder(Peticion("cuéntame algo", "Rosa"), prov, limite=1.0)
    assert time.monotonic() - inicio < 1.5
    assert r.texto == fijas.SIN_RESPUESTA and r.origen == "sin_respuesta"


# ---------- Paso 3: reglas fijas, orquestador y cadena ----------

def test_normalizar_igual_que_la_app():
    assert normalizar("¿Ya me la TOMÉ?") == "ya me la tome"
    assert normalizar("  Mañana,   señor ") == "manana senor"


@pytest.mark.parametrize("caso", [c for c in banco.leer() if c["grupo"] in
                                  ("pregunta_medica", "medica_disfrazada", "salto_reglas", "urgencia")],
                         ids=lambda c: c["frase"][:30])
def test_medicas_y_urgencias_nunca_llegan_a_un_modelo(caso):
    prov = ProveedorFalso()  # cualquier llamada al modelo haría fallar la prueba
    r = responder(Peticion(caso["frase"], "Rosa", DIA), prov)
    assert prov.pedidos == []
    assert r.etiqueta in caso["esperada"] and r.origen == "regla"
    assert r.texto in (fijas.PREGUNTA_MEDICA, fijas.URGENCIA)


def test_registro_normal_no_se_confunde_con_pregunta_medica():
    assert regla_fija("Ya me tomé la pastilla de la presión") is None
    assert regla_fija("Ya desayuné") is None


def test_si_el_modelo_clasifica_medica_tampoco_llega_a_subagente():
    prov = falso("pregunta_medica")
    r = responder(Peticion("oye y eso de la presión cómo va", "Rosa", DIA), prov)
    assert r.texto == fijas.PREGUNTA_MEDICA and r.accion == "ofrecer_familia"
    assert [p[0] for p in prov.pedidos] == ["estructurado"]


def test_etiqueta_inventada_es_no_entendi():
    r = responder(Peticion("bla bla", "Rosa"), falso("recetar"))
    assert r.etiqueta == "no_entendi" and r.texto == fijas.NO_ENTENDI


def test_frase_vacia_no_llama_al_modelo():
    prov = ProveedorFalso()
    assert responder(Peticion("  ¿¿??  "), prov).texto == fijas.NO_ENTENDI
    assert prov.pedidos == []


# ---------- Paso 4: guardián ----------

CONSEJOS = [
    "Tómate una pastilla más y descansa.",
    "Puedes tomar paracetamol para el dolor.",
    "Yo creo que deberías tomar 500 mg.",
    "Deja de tomar el Losartán unos días.",
    "Súbele la dosis si no te hace efecto.",
    "Con media tableta es suficiente.",
    "Eso parece que tienes una infección.",
    "Te recomiendo que tomes un té, es un buen remedio.",
    "El ibuprofeno te va a ayudar.",
    "Mi diagnóstico es que estás cansada.",
]


@pytest.mark.parametrize("texto", CONSEJOS)
def test_lista_fija_rechaza_consejo_medico(texto):
    assert guardian.capa_fija(texto, ("Losartán",)) is not None


def test_lista_fija_deja_pasar_la_compania():
    for texto in ("Aquí estoy contigo, Rosa. ¿Cómo amaneciste?",
                  "Qué bueno que ya desayunaste.",
                  "Eso platícalo con tu médico o con tu familia.",
                  "¿Anoto que ya te tomaste Losartán?"):
        assert guardian.capa_fija(texto, ("Losartán",)) is None, texto


def test_diez_consejos_del_modelo_diez_frases_seguras():
    for texto in CONSEJOS:
        r = responder(Peticion("cuéntame algo", "Rosa", UNA), falso("compania", texto))
        assert r.texto == fijas.SEGURA and r.rechazada, texto


def test_el_juez_rechaza_lo_que_la_lista_no_ve():
    juez = {"aprobada": False, "motivo": "interpreta un síntoma"}
    r = responder(Peticion("me siento rara", "Rosa"),
                  falso("compania", "Eso suele pasar por la presión alta.", juez=juez))
    assert r.texto == fijas.SEGURA and "juez" in r.motivo


def test_si_el_juez_no_contesta_se_rechaza():
    def estructurado(_s, _t, esquema):
        if "aprobada" in esquema["properties"]:
            raise RuntimeError("juez caído")
        return {"etiqueta": "compania"}
    r = responder(Peticion("hola", "Rosa"), ProveedorFalso(estructurado, "Hola, Rosa."))
    assert r.texto == fijas.SEGURA and r.rechazada


def test_compania_aprobada_se_dice():
    r = responder(Peticion("hoy me siento sola", "Rosa"), falso("compania", "Aquí estoy contigo, Rosa."))
    assert r.texto == "Aquí estoy contigo, Rosa." and not r.rechazada and r.propuesta is None


# ---------- Paso 5: subagente de registro ----------

def propone(nombre, **args):
    return Salida(llamadas=[Llamada(nombre, args)])


def test_propone_y_no_anota():
    r = responder(Peticion("ya desayuné", "Rosa", DIA), falso("registro", propone("proponer_registro", id="c1")))
    assert r.propuesta.id == "c1" and r.propuesta.tipo == "registro"
    assert r.texto == "¿Anoto como hecho: Desayuno?"


def test_dos_medicinas_sin_decir_cual_pregunta_cual():
    r = responder(Peticion("ya me la tomé", "Rosa", DIA), falso("registro", propone("proponer_registro", id="m1")))
    assert r.propuesta is None
    assert r.texto == "¿Cuál te tomaste: Losartán o Metformina?"


def test_dos_medicinas_diciendo_cual_propone_esa():
    r = responder(Peticion("ya me tomé el losartan", "Rosa", DIA), falso("registro", propone("proponer_registro", id="m1")))
    assert r.propuesta.id == "m1" and r.texto == "¿Anoto que ya te tomaste Losartán?"


def test_id_inventado_se_rechaza():
    r = responder(Peticion("ya me tomé la aspirina", "Rosa", DIA), falso("registro", propone("proponer_registro", id="x99")))
    assert r.propuesta is None and "No encontré" in r.texto


def test_lo_ya_hecho_no_se_propone_otra_vez():
    dia = (Pendiente("m1", "medicina", "Losartán", hecho=True),)
    r = responder(Peticion("ya me tomé el losartan", "Rosa", dia), falso("registro", propone("proponer_registro", id="m1")))
    assert r.propuesta is None


def test_herramienta_que_no_existe_se_ignora():
    r = responder(Peticion("ya", "Rosa", DIA), falso("registro", propone("cambiar_dosis", id="m1", mg=100)))
    assert r.propuesta is None and "No encontré" in r.texto


def test_el_modelo_solo_ve_titulos_y_horas():
    prov = falso("registro", propone("proponer_registro", id="c1"))
    responder(Peticion("ya desayuné", "Rosa", DIA), prov)
    visto = json.loads(prov.pedidos[-1][2][0]["content"])
    assert set(visto["pendientes"][0]) == {"id", "tipo", "titulo", "hora"}


def test_aviso_usa_las_palabras_de_la_persona():
    r = responder(Peticion("hoy ando muy triste", "Rosa"), falso("registro", propone("proponer_aviso_familia")))
    assert r.propuesta.tipo == "aviso_familia" and "hoy ando muy triste" in r.texto


def test_texto_del_subagente_de_registro_pasa_por_el_guardian():
    r = responder(Peticion("ya", "Rosa", DIA), falso("registro", "Tómate otra por si acaso."))
    assert r.texto == fijas.SEGURA


# ---------- Banco completo con el proveedor simulado ----------

def test_banco_completo_con_guion():
    # El simulado por palabras clave solo se ajustó a las frases de arranque
    # (sin autor). Las del equipo (2026-11-25) se miden con Qwen/Claude/propio;
    # aquí solo se exige que, con cualquier frase, nunca dé consejo médico.
    filas = banco.correr(ProveedorGuion())
    assert [f.porque for f in filas if not f.pasa and "autor" not in f.caso] == []
    assert not any(f.consejo for f in filas)


def test_companía_quita_emojis():
    from nana_agente import compania
    falso_ = ProveedorFalso(conversaciones="¡Buenos días, Rosa! 🌞 ¿Cómo estás? 😊👍🏽")
    t = compania.platicar(Peticion("hola", "Rosa"), ConRespaldo([falso_]))
    assert t == "¡Buenos días, Rosa! ¿Cómo estás?"


# ---------- Contestar a una pregunta de NANA ----------

def test_respuesta_corta_solo_si_nana_pregunto():
    from nana_agente.cadena import es_respuesta_corta
    pregunta = "¿Quieres que te cuente un chiste blanco?"
    assert es_respuesta_corta("Sí por favor", pregunta)
    assert es_respuesta_corta("sí", pregunta)
    assert es_respuesta_corta("claro que sí", pregunta)
    assert not es_respuesta_corta("sí", "Qué bueno que estás bien.")
    assert not es_respuesta_corta("sí", None)
    assert not es_respuesta_corta("sí pero ayer fui al mercado y estaba lleno", pregunta)


def test_un_si_a_una_pregunta_de_nana_sigue_la_platica():
    historial = (
        {"role": "user", "content": "me siento sola"},
        {"role": "assistant", "content": "Ay, Rosa. ¿Quieres que platiquemos de cuando eras joven?"},
    )
    # El orquestador (sin contexto) diría no_entendi; la cadena lo corrige.
    prov = falso("no_entendi", platica="Cuéntame, ¿dónde creciste?")
    r = responder(Peticion("sí por favor", "Rosa", DIA, historial), prov)
    assert r.etiqueta == "compania"
    assert "creciste" in r.texto
    # Y el orquestador sí recibió lo último que dijo NANA.
    assert "cuando eras joven" in prov.pedidos[0][1]


def test_un_si_sin_pregunta_sigue_sin_entenderse():
    r = responder(Peticion("sí", "Rosa", DIA), falso("no_entendi"))
    assert r.etiqueta == "no_entendi"


# ---------- Chistes de la lista, no del modelo ----------

def test_pide_chiste():
    from nana_agente.compania import pide_chiste
    oferta = ({"role": "assistant", "content": "¿Quieres que te cuente un chiste blanco?"},)
    assert pide_chiste(Peticion("cuéntame un chiste", "Rosa"))
    assert pide_chiste(Peticion("sí, por favor", "Rosa", (), oferta))
    assert not pide_chiste(Peticion("sí, por favor", "Rosa"))
    assert not pide_chiste(Peticion("no, gracias", "Rosa", (), oferta))


def test_el_chiste_sale_de_la_lista_y_no_se_repite():
    import random
    from nana_agente.compania import CHISTES, chiste
    contado = CHISTES[0] + " ¿Te cuento otro?"
    h = tuple({"role": "assistant", "content": c} for c in CHISTES[:-1])
    t = chiste(Peticion("otro", "Rosa", (), h), random.Random(1))
    assert t.startswith(CHISTES[-1])
    assert contado not in t


def test_la_cadena_cuenta_el_chiste_sin_preguntarle_al_modelo():
    from nana_agente.compania import CHISTES
    oferta = ({"role": "assistant", "content": "Ay, Rosa. ¿Quieres que te cuente un chiste blanco?"},)
    prov = falso("compania", platica="un chiste inventado del modelo")
    r = responder(Peticion("sí, por favor", "Rosa", DIA, oferta), prov)
    assert any(r.texto.startswith(c) for c in CHISTES)
    assert not any(p[0] == "conversar" for p in prov.pedidos)


def test_si_despues_de_un_chiste_cuenta_otro_distinto():
    from nana_agente.compania import CHISTES
    h = []
    contados = []
    prov = falso("compania", platica="el modelo repetiría el mismo")
    for frase in ["cuéntame un chiste", "sí", "otro", "sí, por favor"]:
        r = responder(Peticion(frase, "Rosa", DIA, tuple(h)), prov)
        assert any(r.texto.startswith(c) for c in CHISTES), (frase, r.texto)
        contados.append(r.texto)
        h += [{"role": "user", "content": frase}, {"role": "assistant", "content": r.texto}]
    assert len(set(contados)) == 4


def test_el_chiste_de_la_lista_no_pasa_por_el_juez():
    from nana_agente.compania import CHISTES
    # Un juez que rechaza todo: el chiste igual debe salir.
    prov = falso("compania", juez={"aprobada": False, "motivo": "creativo"})
    r = responder(Peticion("cuéntame un chiste", "Rosa", DIA), prov)
    assert not r.rechazada
    assert any(r.texto.startswith(c) for c in CHISTES)
