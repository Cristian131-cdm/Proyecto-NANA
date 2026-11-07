# NANA — Nunca Ausente, Nunca Abandonad@

*Cuido · Acompaño · Protejo*

App (Android, iOS y web) que acompaña a personas mayores en su día: medicinas, comidas,
actividad física y ánimo, y avisa a su familia a tiempo. Proyecto integrador de
Administración de Proyectos Tecnológicos, Universidad La Salle Nezahualcóyotl, Grupo 501.

NANA solo **registra, recuerda y alerta** lo que indicó un profesional de la salud. No da
consejos médicos ni cambia dosis.

## Qué hace hoy

- **Persona mayor:** saludo, tarjeta grande con lo que toca ahora, "Ya la tomé", cómo se
  siente, su familia para llamar y "Necesito ayuda". Se adapta si no ve, no oye o no habla.
- **Familia (cuidador):** inicio con alertas (pidió ayuda, medicina sin confirmar, sin
  noticias), medicinas con su ventana, rutinas, la semana, recetas, citas y datos de salud.
- Todo se guarda en Firebase (Auth + Firestore) y se ve en vivo en los dos celulares.
- Letra grande y "Colores más fuertes" para toda la app.

## Cómo correrla

```bash
flutter pub get
flutter run                       # con Firebase (proyecto agente-nana)
flutter run -d chrome             # versión web
flutter test                      # pruebas
```

Sin internet (plan B para presentar), con datos de ejemplo en memoria:

```bash
flutter run -t lib/main_demo.dart                         # como la cuidadora (Ana)
flutter run -t lib/main_demo.dart --dart-define=ROL=adulto  # como la persona mayor (Rosa)
```

Las reglas de Firestore están en `firestore.rules` y se publican con
`firebase deploy --only firestore:rules`.

## Estructura

- `lib/screens/` una pantalla por archivo · `lib/widgets/` piezas reutilizables
- `lib/core/` lógica pura (el día, la semana, alertas, ajustes) · `lib/models/` datos
- `lib/data/` `RepositorioFirebase` (real) y `RepositorioMemoria` (pruebas y demo)
- `docs/superpowers/` diseños y planes
