"""La cadena fija del agente del adulto.

    reglas fijas -> orquestador -> subagente (registro o compañía) -> guardián

El orden está escrito en código. El modelo nunca elige el siguiente paso.
"""

from __future__ import annotations

import time

from . import compania, frases_fijas as fijas, guardian, mi_dia, registro
from .modelos import Peticion, Resultado
from .orquestador import clasificar
from .proveedor import ConRespaldo, ProveedorModelo, SinRespuesta
from .reglas import normalizar, regla_fija

TOPE_FRASE = 300
LIMITE = 5.0

# Contestaciones cortas a una pregunta de NANA.
CORTAS = ("si", "no", "claro", "por favor", "cuentame", "dale", "ok", "va",
          "sale", "andale", "orale", "bueno", "esta bien", "me gustaria", "quiero")


def _ultimo_de_nana(pet: Peticion) -> str | None:
    for m in reversed(pet.historial):
        if m.get("role") == "assistant":
            return str(m.get("content", "")) or None
    return None


def es_respuesta_corta(texto: str, antes: str | None) -> bool:
    """¿Contesta, en pocas palabras, a algo que NANA acaba de preguntar?"""
    if not antes or "?" not in antes:
        return False
    t = normalizar(texto)
    if not t or len(t.split()) > 5:
        return False
    return any(f" {c} " in f" {t} " for c in CORTAS)


def responder(
    pet: Peticion, proveedor: ProveedorModelo, limite: float = LIMITE
) -> Resultado:
    inicio = time.monotonic()
    prov = proveedor if isinstance(proveedor, ConRespaldo) else ConRespaldo([proveedor])
    prov.usado = None
    prov.fallas = []

    def resto() -> float:
        r = limite - (time.monotonic() - inicio)
        if r <= 0:
            raise SinRespuesta("se acabó el tiempo")
        return r

    def fin(r: Resultado) -> Resultado:
        r.segundos = round(time.monotonic() - inicio, 3)
        r.proveedor = prov.usado or ""
        r.fallas = list(prov.fallas)
        return r

    pet = Peticion(pet.texto.strip()[:TOPE_FRASE], pet.nombre, pet.dia, pet.historial)
    if not normalizar(pet.texto):
        return fin(Resultado("no_entendi", fijas.NO_ENTENDI))

    etiqueta = regla_fija(pet.texto)
    origen = "regla" if etiqueta else "modelo"
    antes = _ultimo_de_nana(pet)
    try:
        if etiqueta is None:
            etiqueta = clasificar(pet.texto, prov, resto(), antes=antes)
            # Red de seguridad, sin modelo: si NANA acaba de preguntar algo y
            # la persona contesta corto ("sí", "sí por favor"), sigue la plática.
            if etiqueta == "no_entendi" and es_respuesta_corta(pet.texto, antes):
                etiqueta = "compania"

        # Estas nunca llegan a un subagente: respuesta fija o del código.
        if etiqueta == "pregunta_medica":
            return fin(Resultado(etiqueta, fijas.PREGUNTA_MEDICA, origen, "ofrecer_familia"))
        if etiqueta == "urgencia":
            return fin(Resultado(etiqueta, fijas.URGENCIA, origen, "abrir_ayuda"))
        if etiqueta == "familia":
            return fin(Resultado(etiqueta, fijas.FAMILIA, origen, "abrir_familia"))
        if etiqueta == "no_entendi":
            return fin(Resultado(etiqueta, fijas.NO_ENTENDI, origen))
        if etiqueta == "mi_dia":
            return fin(Resultado(etiqueta, mi_dia.contestar(pet), origen, "abrir_mi_dia"))

        if etiqueta == "registro":
            propuesta, texto = registro.proponer(pet, prov, resto())
            if propuesta is not None:
                return fin(Resultado(etiqueta, propuesta.pregunta, origen, propuesta=propuesta))
            if registro.es_del_codigo(texto):
                return fin(Resultado(etiqueta, texto, origen))
        else:
            texto = compania.platicar(pet, prov, resto())

        if not texto.strip():
            return fin(Resultado(etiqueta, fijas.NO_ENTENDI, origen))
        permitidas = tuple(p.titulo for p in pet.dia if p.tipo == "medicina")
        veredicto = guardian.revisar(texto, prov, permitidas, resto())
        if not veredicto.aprobada:
            return fin(Resultado(etiqueta, fijas.SEGURA, origen, rechazada=True,
                                 motivo=f"{veredicto.capa}: {veredicto.motivo}"))
        return fin(Resultado(etiqueta, texto, origen))
    except SinRespuesta:
        return fin(Resultado(etiqueta or "no_entendi", fijas.SIN_RESPUESTA, "sin_respuesta"))
