# NANA B — preparación de recursos

Diseño elegido por Cris en este chat: variante B con volumen suave, blanco y lila, pantalla oscura y corazón. Preparación de todos los recursos autorizada el 11 de noviembre de 2026.

Alternativas: A plana y B con volumen; Cris eligió B. Para acciones pequeñas se mantienen SVG sencillos; para la mascota se conserva la ilustración B. El ícono del teléfono es una adaptación vectorial simplificada de B, no un recorte del PNG.

1. Generar cuatro estados PNG transparentes mediante image_gen usando B como referencia.
2. Dibujar seis SVG propios y un ícono de aplicación con fuente SVG y exportaciones PNG; mantener carpetas nuevas para evitar sobrescrituras.
3. Preparar galería local, manifiesto con SHA-256, prompts e instrucciones para Claude.
4. Verificar transparencia, tamaño, integridad, SVG sin scripts/recursos externos y representación visual. Copiar el paquete al worktree y verificar que solo se agregaron recursos nuevos.

Alcance: entrega de recursos, no rediseño del panel ni integración Flutter. No modificar pubspec, tema, mascota actual, código de voz, pantallas o íconos actuales. No merge ni push. Las imágenes estáticas no reemplazan por sí solas el parpadeo ni el movimiento del corazón.

Verificación: ejecutar preparar.cjs, inspeccionar galeria.html, comprobar PNG con Pillow en modo lectura, analizar SVG con ElementTree y comparar hashes después de copiar. No aplica ejecutar pruebas Flutter porque no se modifica código ni configuración de la aplicación.
