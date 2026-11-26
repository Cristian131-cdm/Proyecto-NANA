# Avisos de NANA (Cloudflare Worker)

**Desplegado** (2026-11-25, cuenta del proyecto): `https://nana-avisos.nana-agente.workers.dev` · cron cada 5 min.

Manda push a la familia **aunque la app esté cerrada**:

| Qué | Cuándo |
|---|---|
| «Rosa necesita ayuda» / «Rosa dijo…» | Al instante: la app llama a `POST /ahora` después de crear la alerta (y el cron la recoge si eso falla). |
| «Rosa no ha marcado su Losartán» | Hora + 2 ventanas sin marcar (si «medicina» está prendida en Familia y alertas). |
| «Hace rato que no sabemos de Rosa» | Más de `horasSinNoticias` sin actividad, una vez al día. |

Los textos son fijos (`src/reglas.ts`): las alertas nunca dependen de un modelo.
FCM es gratis en el plan Spark de Firebase, así que no hace falta Blaze.

## Subirlo (una sola vez)

1. Crear una cuenta en Cloudflare (gratis).
2. En esta carpeta:
   ```powershell
   npx wrangler login
   ```
3. Firebase → Configuración del proyecto → **Cuentas de servicio** → *Generar nueva clave privada*.
   Se baja un `.json`. Subirlo como secreto y **borrar el archivo** después:
   ```powershell
   Get-Content "$env:USERPROFILE\Downloads\agente-nana-xxxx.json" -Raw | npx wrangler secret put CUENTA_SERVICIO
   ```
4. Publicarlo (la primera vez, **desde tu terminal**: pide registrar el subdominio `workers.dev`;
   la liga de «onboarding» que da el error lleva a un 404):
   ```powershell
   npx wrangler deploy
   ```
   Imprime la dirección `https://nana-avisos.<tu-subdominio>.workers.dev`. Esa va en la app
   (`urlAvisos` en `lib/core/push.dart`, o `--dart-define=NANA_AVISOS=...`).
5. Revisar: abrir `https://…workers.dev/salud` → `{"ok":true,"cuenta":true}`.

## Pruebas

```powershell
npm test            # 9 pruebas con una nube falsa
npx tsc --noEmit    # tipos
npx wrangler dev --test-scheduled   # local; luego abrir /__scheduled para correr el cron
```

## Costos (plan gratis)

- Cloudflare: 100 000 peticiones al día; el cron cada 5 min usa 288.
- Firestore Spark: 50 000 lecturas al día; cada revisión lee ~8 documentos por persona
  (~2 300 al día por persona).
