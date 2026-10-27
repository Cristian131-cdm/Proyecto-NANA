# Expediente de salud del adulto — diseño

Fecha: 2026-10-27 · Rama: `feature/rediseno-accesible` · Plan aprobado por Cris.

## Para qué
Al registrar al adulto mayor, la familia puede anotar qué padece (a mano) o subir su expediente
(PDF o foto) para que NANA llene el formulario. Antes de guardar, la familia **revisa, corrige y
confirma**. La pestaña Historial deja de usar datos de ejemplo para la salud.

## Límites
- NANA no sustituye el criterio médico: solo guarda lo que indicó un profesional y lo que confirma la
  familia. No diagnostica ni recomienda.
- El documento **no se sube ni se guarda** en ningún lado; solo se guardan los datos confirmados.

## Fase 1 — Formulario (real)
- `Salud` (`lib/models/salud.dart`): padecimientos, alergias, medicamentos que menciona el expediente,
  discapacidades (lista fija), peso, estatura, notas, origen (`manual` | `documento`).
- Firestore: mapa `salud` dentro de `adultos/{folio}` (con `actualizado` y `actualizadoPor`). Las reglas
  existentes ya permiten que la familia lo edite.
- `FormularioSalud` aparece después del alta del cuidador (antes del código o del aviso "sin celular"),
  después del registro del adulto, y desde Historial → "Editar datos de salud". "Lo hago después" lo salta.

## Fase 2 — Lectura del expediente (simulada, decisión de Cris)
- "Subir expediente (PDF o foto)" abre el selector de archivos (`file_picker`; PDF, JPG o PNG, máx. 10 MB).
- `LectorSimulado` espera 2 s y regresa datos de ejemplo. La pantalla de revisión lo dice claro:
  "Demostración: NANA todavía no lee el documento de verdad".
- Para leerlo de verdad se cambia `Servicios.lector` por un lector que llame a una Cloud Function con
  Claude (necesita el plan Blaze y la API key). Las pantallas no cambian. Diseño de referencia en
  `~/.claude/plans/vectorized-wibbling-crayon.md` (sección "Referencia futura").
