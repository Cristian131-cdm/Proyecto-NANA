"""«¿Qué me toca hoy?»: lo contesta el código, nunca un modelo."""

from nana_agente import banco, mi_dia
from nana_agente.cadena import responder
from nana_agente.modelos import Pendiente, Peticion
from nana_agente.proveedor import ProveedorFalso
from nana_agente.reglas import regla_fija

DIA = banco.DIA


def pet(texto, dia=DIA):
    return Peticion(texto, "Rosa", dia)


def test_regla_atrapa_preguntas_de_horario():
    for frase in ("¿Qué me toca el día de hoy?", "¿A qué hora me toca tomar mi pastilla?",
                  "¿A qué hora me tomo el Losartán?", "¿Qué sigue?", "¿Cuándo me toca comer?"):
        assert regla_fija(frase) == "mi_dia", frase


def test_la_urgencia_le_gana_a_mi_dia():
    assert regla_fija("Me caí, ¿qué me toca hacer?") == "urgencia"


def test_la_pregunta_medica_sigue_siendo_medica():
    assert regla_fija("¿Qué pastilla me tomo para el dolor?") == "pregunta_medica"


def test_todo_el_dia_agrupado_por_hora():
    t = mi_dia.contestar(pet("¿Qué me toca hoy?"))
    assert t == ("Hoy te toca a las 8:00 Losartán y Metformina, a las 9:00 Desayuno "
                 "y a las 10:00 Caminar 15 minutos.")


def test_solo_las_medicinas_si_pregunta_por_la_pastilla():
    t = mi_dia.contestar(pet("¿A qué hora me toca tomar mi pastilla?"))
    assert t == "Te toca a las 8:00 Losartán y Metformina."


def test_por_nombre():
    assert mi_dia.contestar(pet("¿A qué hora es mi Metformina?")) == "Te toca a las 8:00 Metformina."


def test_lo_hecho_se_dice_aparte():
    dia = (Pendiente("m1", "medicina", "Losartán", "8:00", hecho=True),
           Pendiente("m2", "medicina", "Metformina", "20:00"))
    t = mi_dia.contestar(pet("¿A qué hora me toca mi medicina?", dia))
    assert t == "Te toca a las 20:00 Metformina. Ya está anotado: Losartán."


def test_todo_hecho():
    dia = (Pendiente("m1", "medicina", "Losartán", "8:00", hecho=True),)
    t = mi_dia.contestar(pet("¿Qué me toca?", dia))
    assert "Ya no te falta nada" in t


def test_lista_vacia():
    assert mi_dia.contestar(pet("¿Qué me toca?", ())) == mi_dia.LISTA_VACIA


def test_la_cadena_no_le_pregunta_al_modelo():
    nadie = ProveedorFalso()  # truena si alguien le pregunta algo
    r = responder(pet("¿Qué me toca el día de hoy?"), nadie)
    assert r.etiqueta == "mi_dia"
    assert r.origen == "regla"
    assert r.accion == "abrir_mi_dia"
    assert r.texto.startswith("Hoy te toca")
    assert nadie.pedidos == []


def test_si_el_orquestador_dice_mi_dia_contesta_el_codigo():
    solo_clasifica = ProveedorFalso({"etiqueta": "mi_dia"})
    r = responder(pet("¿Me falta algo?"), solo_clasifica)
    assert r.etiqueta == "mi_dia"
    assert "Losartán" in r.texto
    assert [p[0] for p in solo_clasifica.pedidos] == ["estructurado"]
