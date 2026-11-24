"""Las plantillas de Excel del equipo: se hacen bien y se juntan bien."""

from openpyxl import load_workbook

import hacer_plantillas as hp
import juntar_frases as jf
from nana_agente import banco


def _llenar(archivo, hoja, frases):
    """Escribe frases en la columna C, como lo haría alguien del equipo."""
    wb = load_workbook(archivo)
    ws = wb[hoja]
    for i, frase in enumerate(frases, 3):  # renglón 2 = ejemplo
        ws.cell(row=i, column=3, value=frase)
    wb.save(archivo)


def test_la_plantilla_trae_el_reparto(tmp_path):
    archivo = hp.plantilla("Valeria", "viernes 28", tmp_path)
    wb = load_workbook(archivo)
    assert wb.sheetnames == ["Instrucciones", "Frases", "Temas", "Prueba"]
    frases = [r for r in wb["Frases"].iter_rows(min_row=3, max_col=2, values_only=True)]
    etiquetas = [e for _, e in frases]
    assert len(etiquetas) == sum(hp.REPARTO.values()) == 27
    assert etiquetas.count("urgencia") == 5
    assert wb["Frases"]["A2"].value == "Ej."
    assert len(list(wb["Temas"].iter_rows(min_row=3))) == 6
    assert len(list(wb["Prueba"].iter_rows(min_row=3))) == 5
    assert wb["Frases"].data_validations.dataValidation  # lista desplegable


def test_juntar_lee_lo_escrito_y_salta_vacios(tmp_path):
    archivo = hp.plantilla("Edgar", "viernes 28", tmp_path)
    _llenar(archivo, "Frases", ["Ay me resbalé en la cocina y no me levanto", "", "Bueno días Nanita"])
    _llenar(archivo, "Prueba", ["Uy me dio un mareo bien feo y me caí"])
    r = jf.juntar(tmp_path)
    assert len(r.entrenamiento) == 2
    assert r.entrenamiento[0]["autor"] == "Edgar"
    assert len(r.prueba) == 1
    p = r.prueba[0]
    assert p["grupo"] == p["esperada"][0]
    assert p["grupo"] in banco.GRUPOS
    assert r.por_autor["Edgar"] == 3


def test_salta_repetidas_y_las_del_banco_de_prueba(tmp_path):
    archivo = hp.plantilla("Alan", "viernes 28", tmp_path)
    ya_en_prueba = banco.leer()[0]["frase"]
    _llenar(archivo, "Frases", [ya_en_prueba, "Márcale a mi hija la grande", "márcale a mi hija la grande"])
    r = jf.juntar(tmp_path)
    assert [f["frase"] for f in r.entrenamiento] == ["Márcale a mi hija la grande"]
    assert any("frases.jsonl (prueba)" in a for a in r.avisos)
    assert any("ya está en" in a for a in r.avisos)


def test_etiqueta_cambiada_a_mano_que_no_existe(tmp_path):
    archivo = hp.plantilla("Dylan", "viernes 28", tmp_path)
    wb = load_workbook(archivo)
    wb["Frases"]["B3"] = "chisme"
    wb["Frases"]["C3"] = "Oye ya supiste lo de la vecina"
    wb.save(archivo)
    r = jf.juntar(tmp_path)
    assert r.entrenamiento == []
    assert any("«chisme» no existe" in a for a in r.avisos)
