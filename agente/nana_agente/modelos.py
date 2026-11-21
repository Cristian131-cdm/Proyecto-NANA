"""Los datos que entran y salen del agente."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

TIPOS = ("medicina", "comida", "ejercicio", "otro")


@dataclass(frozen=True)
class Pendiente:
    """Algo de la lista de hoy de la persona. Solo título y hora; nada de dosis."""

    id: str
    tipo: str
    titulo: str
    hora: str = ""
    hecho: bool = False


@dataclass(frozen=True)
class Peticion:
    texto: str
    nombre: str = ""
    dia: tuple[Pendiente, ...] = ()
    # Últimos turnos de la plática: [{"role": "user"|"assistant", "content": str}]
    historial: tuple[dict, ...] = ()

    @staticmethod
    def de_json(d: dict) -> "Peticion":
        dia = tuple(
            Pendiente(
                id=str(p["id"]),
                tipo=p.get("tipo") if p.get("tipo") in TIPOS else "otro",
                titulo=str(p.get("titulo", ""))[:80],
                hora=str(p.get("hora", ""))[:10],
                hecho=bool(p.get("hecho", False)),
            )
            for p in (d.get("dia") or [])[:30]
            if isinstance(p, dict) and "id" in p
        )
        historial = tuple(
            {"role": h["role"], "content": str(h["content"])[:400]}
            for h in (d.get("historial") or [])[-6:]
            if isinstance(h, dict) and h.get("role") in ("user", "assistant") and h.get("content")
        )
        return Peticion(
            texto=str(d.get("texto", "")),
            nombre=str(d.get("nombre", ""))[:40],
            dia=dia,
            historial=historial,
        )


@dataclass(frozen=True)
class Propuesta:
    """Lo que NANA propone anotar. Nunca se anota sin que la persona diga que sí."""

    tipo: str  # 'registro' | 'animo' | 'aviso_familia'
    pregunta: str
    id: str = ""
    titulo: str = ""
    clase: str = ""  # tipo del pendiente: medicina, comida...
    valor: int = 0  # ánimo 1 a 5


@dataclass
class Resultado:
    etiqueta: str
    texto: str
    # 'regla' (sin modelo) | 'modelo' | 'sin_respuesta'
    origen: str = "regla"
    # 'abrir_ayuda' | 'abrir_familia' | 'ofrecer_familia' | 'abrir_mi_dia' | ''
    accion: str = ""
    propuesta: Propuesta | None = None
    rechazada: bool = False
    motivo: str = ""
    proveedor: str = ""
    segundos: float = 0.0
    fallas: list[str] = field(default_factory=list)

    def a_json(self) -> dict:
        return asdict(self)
