"""Hace una plantilla de Excel por integrante para que escriba frases de NANA.

    python hacer_plantillas.py <carpeta_destino> [--entrega "viernes 28 de noviembre"]

Cada archivo trae la etiqueta ya puesta en cada renglón (según el reparto) y la
persona solo escribe la frase. Al regresar: python juntar_frases.py <carpeta>.
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.worksheet.datavalidation import DataValidation

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nana_agente.entrenamiento import TEMAS  # noqa: E402
from nana_agente.frases_fijas import ETIQUETAS  # noqa: E402

EQUIPO = ("Dulce", "Cris", "Valeria", "Edgar", "Elias", "Dylan", "Alan")

# Cuántas de cada etiqueta escribe cada quien (27). Las que más faltan, más.
REPARTO = {
    "urgencia": 5, "compania": 5, "registro": 4, "pregunta_medica": 4,
    "mi_dia": 4, "familia": 3, "no_entendi": 2,
}
TEMAS_POR_PERSONA = ("soledad", "cansancio", "alegria", "recuerdos", "tristeza", "saludo")
# Frases que NO se usan para entrenar: van al banco de prueba.
PRUEBA_POR_PERSONA = ("urgencia", "pregunta_medica", "mi_dia", "compania", "registro")

QUE_ES = {
    "urgencia": "Se cayó, le duele algo fuerte, no puede respirar o pide ayuda YA",
    "compania": "Quiere platicar, saluda, se siente sola, cuenta algo",
    "registro": "Dice que YA hizo algo de su día (medicina, comida, caminar) o cómo amaneció",
    "pregunta_medica": "Pregunta qué tomar, cuánto, si puede cambiar o dejar una medicina",
    "mi_dia": "Pregunta qué le toca hoy o a qué hora es algo de su lista",
    "familia": "Quiere hablar con alguien de su familia o que le avisen",
    "no_entendi": "Pedazos sin sentido que salen del dictado",
}
EJEMPLOS = {
    "urgencia": "Me fui de lado en el baño y no me puedo parar",
    "compania": "Ay mija, hoy nadie me ha venido a ver",
    "registro": "Ya me tomé la de la presión con mi cafecito",
    "pregunta_medica": "¿Me tomo otra si sigo con dolor?",
    "mi_dia": "¿Qué me toca después de comer?",
    "familia": "Márcale a mi Lupe porfa",
    "no_entendi": "este eh la que",
}
TEMA_QUE_ES = {
    "saludo": "Saluda", "soledad": "Se siente sola", "tristeza": "Está triste",
    "alegria": "Está contenta", "gracias": "Da las gracias", "recuerdos": "Cuenta un recuerdo",
    "cansancio": "Está cansada", "despedida": "Se despide", "platica": "Quiere platicar",
    "fuera_de_tema": "Pregunta algo de otro tema",
}

ARIAL = "Arial"
MORADO = "5B3FA8"
LILA = "EDE7FA"
AMARILLO = "FFF4C2"  # las celdas que hay que llenar
GRIS = "6B6485"
FINO = Side(style="thin", color="DDD6F3")
BORDE = Border(left=FINO, right=FINO, top=FINO, bottom=FINO)


def _encabezado(ws, columnas: list[tuple[str, int]]):
    for i, (titulo, ancho) in enumerate(columnas, 1):
        c = ws.cell(row=1, column=i, value=titulo)
        c.font = Font(name=ARIAL, bold=True, color="FFFFFF", size=11)
        c.fill = PatternFill("solid", fgColor=MORADO)
        c.alignment = Alignment(vertical="center", wrap_text=True)
        ws.column_dimensions[c.column_letter].width = ancho
    ws.row_dimensions[1].height = 30
    ws.freeze_panes = "A3"


def _fila(ws, r: int, valores: list, ejemplo: bool = False):
    for i, v in enumerate(valores, 1):
        c = ws.cell(row=r, column=i, value=v)
        c.font = Font(name=ARIAL, size=11, italic=ejemplo, color=GRIS if ejemplo else "222222")
        c.alignment = Alignment(vertical="center", wrap_text=True)
        c.border = BORDE
    # La columna de la frase (C) es la que se llena: amarilla.
    if not ejemplo:
        ws.cell(row=r, column=3).fill = PatternFill("solid", fgColor=AMARILLO)
    ws.row_dimensions[r].height = 30


def _hoja_frases(wb, titulo: str, etiquetas: list[str], opciones: tuple[str, ...],
                 que_es: dict, ejemplos: dict, autor: str, campo: str):
    ws = wb.create_sheet(titulo)
    _encabezado(ws, [("#", 6), (campo.capitalize(), 18), ("✍️ Escribe aquí la frase", 58),
                     ("Qué es esta " + campo, 72), ("Autor", 12)])
    primera = etiquetas[0]
    _fila(ws, 2, ["Ej.", primera, ejemplos.get(primera, "…"), que_es[primera], autor], ejemplo=True)
    for n, e in enumerate(etiquetas, 1):
        _fila(ws, n + 2, [n, e, None, que_es[e], autor])
    dv = DataValidation(type="list", formula1='"' + ",".join(opciones) + '"', allow_blank=False,
                        showErrorMessage=True, errorTitle="Etiqueta",
                        error="Elige una de la lista.")
    ws.add_data_validation(dv)
    dv.add(f"B3:B{len(etiquetas) + 2}")
    return ws


def _instrucciones(wb, nombre: str, entrega: str):
    ws = wb.active
    ws.title = "Instrucciones"
    ws.column_dimensions["A"].width = 22
    ws.column_dimensions["B"].width = 95
    renglones = [
        ("titulo", f"Frases para NANA — {nombre}"),
        ("", ""),
        ("Para qué", "NANA aprende a entender a las personas mayores con estas frases. Hoy todas las "
                     "escribió la IA: con las del equipo entiende mejor cómo habla la gente de verdad."),
        ("Cuánto tarda", "Unos 20 minutos. Son 27 frases en «Frases», 6 en «Temas» y 5 en «Prueba»."),
        ("Qué hacer", "En cada hoja la etiqueta ya viene puesta. Solo escribe la frase en la celda "
                      "AMARILLA de cada renglón. El renglón gris de «Ej.» es un ejemplo: no lo borres."),
        ("Entrega", f"Guarda el archivo (sin cambiarle el nombre) y mándaselo a Cris por WhatsApp a más "
                    f"tardar el {entrega}."),
        ("", ""),
        ("subtitulo", "Reglas"),
        ("1. Como habla la gente", "Con modismos y diminutivos: «ya me la tomé mija», «ando de malas», "
                                   "«márcale a mi'jo». Frases a medias también."),
        ("2. Variedad", "Que no sea la misma frase con una palabra cambiada."),
        ("3. Errores de dictado", "Algunas como las escribiría mal el celular: «lozartan», «oye nena»."),
        ("4. No copies", "No copies frases de otros ni de internet. Inventa como hablaría tu abuelita."),
        ("5. «Prueba» es aparte", "Las de la hoja «Prueba» sirven para examinar a NANA: no se usan "
                                  "para entrenarla. Que sean distintas a las que pusiste en «Frases»."),
        ("", ""),
        ("subtitulo", "Qué significa cada etiqueta"),
    ] + [(e, f"{QUE_ES[e]}.  Ej.: «{EJEMPLOS[e]}»") for e in ETIQUETAS]
    for r, (a, b) in enumerate(renglones, 1):
        if a == "titulo":
            c = ws.cell(row=r, column=1, value=b)
            c.font = Font(name=ARIAL, bold=True, size=18, color=MORADO)
            ws.row_dimensions[r].height = 30
            continue
        if a == "subtitulo":
            c = ws.cell(row=r, column=1, value=b)
            c.font = Font(name=ARIAL, bold=True, size=13, color=MORADO)
            continue
        ca = ws.cell(row=r, column=1, value=a)
        cb = ws.cell(row=r, column=2, value=b)
        ca.font = Font(name=ARIAL, bold=True, size=11)
        cb.font = Font(name=ARIAL, size=11)
        cb.alignment = Alignment(wrap_text=True, vertical="top")
        ca.alignment = Alignment(vertical="top")
        if a in QUE_ES:
            ca.fill = PatternFill("solid", fgColor=LILA)


def plantilla(nombre: str, entrega: str, destino: Path) -> Path:
    azar = random.Random(f"nana-{nombre}")
    etiquetas = [e for e, n in REPARTO.items() for _ in range(n)]
    azar.shuffle(etiquetas)
    temas = list(TEMAS_POR_PERSONA)
    azar.shuffle(temas)
    prueba = list(PRUEBA_POR_PERSONA)
    azar.shuffle(prueba)

    wb = Workbook()
    _instrucciones(wb, nombre, entrega)
    _hoja_frases(wb, "Frases", etiquetas, ETIQUETAS, QUE_ES, EJEMPLOS, nombre, "etiqueta")
    _hoja_frases(wb, "Temas", temas, TEMAS, TEMA_QUE_ES,
                 {"soledad": "Desde que se fue mi viejo la casa se siente bien grande"}, nombre, "tema")
    _hoja_frases(wb, "Prueba", prueba, ETIQUETAS, QUE_ES,
                 {"urgencia": "Ay, me pegué en la cabeza y veo todo borroso"}, nombre, "etiqueta")
    archivo = destino / f"NANA_frases_{nombre}.xlsx"
    wb.save(archivo)
    return archivo


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("destino", type=Path)
    ap.add_argument("--entrega", default="día que diga Cris")
    a = ap.parse_args()
    a.destino.mkdir(parents=True, exist_ok=True)
    for nombre in EQUIPO:
        print("Hice", plantilla(nombre, a.entrega, a.destino))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
