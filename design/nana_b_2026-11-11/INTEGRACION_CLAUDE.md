# NANA B — entrega para Claude

Cris eligió la opción B y pidió preparar la mascota, sus expresiones, el ícono del teléfono y los íconos de acciones. Los archivos de este paquete son nuevos; no se cambió la aplicación ni se hizo merge.

## Recursos

- `assets/mascota_b/nana_normal.png`: saludo y presencia habitual.
- `assets/mascota_b/nana_contenta.png`: expresión alegre.
- `assets/mascota_b/nana_atenta.png`: algo requiere atención; no alarma de emergencia por sí sola.
- `assets/mascota_b/nana_dormida.png`: descanso.
- `assets/icono_b/icono.png`: 1024 × 1024, fondo morado opaco, fuente `icono.svg`.
- `assets/icono_b/icono_frente.png`: primer plano Android 1024 × 1024 transparente, fuente `icono_frente.svg`; motivo dentro del círculo seguro central, fondo separado `#5B3FA8`.
- `assets/icono_b/icono_48.png`, `_96.png`, `_192.png`, `_512.png`: exportaciones del SVG para revisión y web.
- `assets/iconos_b/`: SVG originales (no copias de Phosphor), viewBox 24 × 24, trazo 2, extremos redondeados y color base `#5B3FA8`.

| SVG | Texto visible / acción |
|---|---|
| pastilla.svg | Mis medicamentos |
| hablar.svg | Hablar con NANA |
| familia.svg | Mi familia |
| mi_dia.svg | Mi día |
| ayuda.svg | Necesito ayuda |
| nana.svg | NANA, símbolo pequeño |

Los nombres y etiquetas se adaptan al contexto existente, sin cambiar el comportamiento de una acción.

## Integración pendiente (a cargo de Claude)

1. Copiar `assets/mascota_b`, `assets/iconos_b` y `assets/icono_b` a la raíz del repo y declarar esas rutas en `flutter.assets` del pubspec. Agregar `flutter_svg` solo si aún no existe. El paquete está en `design/nana_b_2026-11-11/` del worktree para que el merge no sustituya archivos actuales.
2. Mapear los cuatro PNG a `EstadoNana`. Mantener tamaño fijo y `BoxFit.contain`. No sustituir de golpe `MascotaNana` por una imagen si eso elimina `ojosCerrados`, `escalaCorazon`, estados de voz o accesibilidad. Estos PNG son estados estáticos, no cuadros consecutivos de animación; pueden presentar variaciones mínimas entre siluetas. Para animación continua, recrear las facciones en CustomPainter sobre una carcasa separada o preparar esa capa como una siguiente tarea. El parpadeo no se obtiene alternando normal/dormida.
3. Para SVG, usar el color de `ColoresNana` mediante `ColorFilter.mode(color, BlendMode.srcIn)` (sin hex sueltos en widgets). Mantener el filtro de alto contraste existente. El ícono de ayuda debe usar el color de alerta del tema en contexto.
4. Cada botón conserva texto visible, tamaño táctil de al menos 64 px y una única etiqueta accesible. Con texto ya incluido en el botón, excluir la semántica redundante del dibujo. Si el SVG es el único contenido, asignar semanticLabel al control. La emoción de NANA no será la única forma de comunicar un aviso.
5. Cambiar `flutter_launcher_icons.image_path` y `adaptive_icon_foreground` hacia los nuevos PNG, conservando `adaptive_icon_background: '#5B3FA8'`, `remove_alpha_ios: true` y la configuración web. Ejecutar el generador existente y comprobar máscara circular, cuadrada y squircle en Android. No ejecutar `tool/generar_iconos.dart` apuntando a estos archivos: volvería a dibujar el diseño anterior.
6. Mantener el splash actual hasta decidir su adaptación. El paquete no incluye un nuevo splash nativo ni estados de hablando/escuchando.
7. Verificar `flutter analyze` y `flutter test`; pegar sus resultados. En el dispositivo revisar texto grande, Colores más fuertes, TalkBack/VoiceOver, Menos movimiento, voz, recordatorio y carga sin saltos. Revisar íconos en 24/32/48 px y confirmar su comprensión con los usuarios.

## Procedencia y revisión

Mascota: imagen B aprobada como referencia, editada con la herramienta integrada image_gen; prompts exactos en `prompts.json`. PNG con canal alfa, sin edición por scripts. Íconos: SVG dibujados por Codex; el ícono de app usa gradientes sencillos, rasterizado con Sharp. `manifest.json` guarda los hashes de los recursos; `galeria.html` funciona sin conexión.

La preparación de recursos no equivale a integración ni a prueba en Flutter. No se tocaron pubspec, tema, pantallas, servicios, animaciones o íconos originales. Merge y conexión final quedan en manos de Cris/Claude según el reparto del proyecto.
