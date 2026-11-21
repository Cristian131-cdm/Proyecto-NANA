"""Lo que NANA contesta sin preguntarle a ningún modelo."""

ETIQUETAS = (
    "registro",
    "compania",
    "pregunta_medica",
    "urgencia",
    "familia",
    # Pregunta qué le toca hoy o a qué hora. Contesta el código con su lista.
    "mi_dia",
    "no_entendi",
)

PREGUNTA_MEDICA = (
    "Eso pregúntaselo a tu médico o a tu familia. "
    "¿Quieres que le avise a tu familia?"
)
URGENCIA = "Voy a pedir ayuda. Toca el botón para avisarle a tu familia."
FAMILIA = "Vamos con tu familia."
NO_ENTENDI = "No te entendí. Puedes tocar lo que me quieres decir."
# El modelo no contestó a tiempo (o no hay ninguno disponible).
SIN_RESPUESTA = "Ahorita no puedo platicar, pero aquí están tus botones."
# El guardián rechazó lo que el modelo quería decir.
SEGURA = (
    "De eso no te puedo decir. Mejor pregúntale a tu médico o a tu familia."
)
TOPE_DIARIO = "Por hoy ya platicamos mucho. Aquí siguen tus botones."
