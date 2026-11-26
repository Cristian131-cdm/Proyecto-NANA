// Worker de avisos de NANA (Cloudflare, plan gratis).
//
//   cron cada minuto  → revisa a cada persona: alertas sin push, medicinas sin
//                        marcar y «sin noticias» → push a su familia.
//   POST /ahora {folio} → la app lo llama justo después de «Necesito ayuda»
//                        para no esperar al cron. Solo revisa ese folio; no
//                        devuelve datos, así que no hace falta sesión.
//   GET /salud         → para ver que está vivo.

import { NubeGoogle, type Nube } from './google';
import { inicioDelDia, pushDeAlertas, pushDeMedicinas, pushSinNoticias, type Push } from './reglas';

export interface Env {
  CUENTA_SERVICIO: string; // secreto: JSON de la cuenta de servicio de Firebase
  DESFASE_MIN?: string; // minutos respecto a UTC (México: -360)
}

const desfase = (env: Env) => Number(env.DESFASE_MIN ?? '-360');
const folioValido = (f: unknown): f is string => typeof f === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(f);

async function mandar(nube: Nube, folio: string, uidAdulto: string | null, p: Push): Promise<number> {
  // Primero se aparta la clave: si otro cron ya lo mandó, no se repite.
  if (!(await nube.apartar(`${folio}_${p.clave}`))) return 0;
  const uids = p.para === 'adulto' ? (uidAdulto ? [uidAdulto] : []) : await nube.uidsFamilia(folio);
  let enviados = 0;
  for (const uid of uids) {
    for (const t of await nube.tokens(uid)) {
      if (await nube.enviar(t, p.titulo, p.cuerpo, { ...p.datos, folio })) enviados++;
    }
  }
  return enviados;
}

export async function revisar(nube: Nube, folio: string, ahora: Date, desfaseMin: number, completo = true): Promise<number> {
  const adulto = await nube.adulto(folio);
  if (!adulto) return 0;
  let enviados = 0;

  for (const p of pushDeAlertas(adulto.nombre, await nube.alertasSinAtender(folio), ahora, desfaseMin)) {
    enviados += await mandar(nube, folio, adulto.uidAdulto, p);
    await nube.marcarAlerta(folio, p.datos.alerta);
  }
  if (!completo) return enviados;

  const tomadas = await nube.tomadasDesde(folio, inicioDelDia(ahora, desfaseMin));
  const pushes = [
    ...pushDeMedicinas(adulto.nombre, await nube.medicinas(folio), tomadas, adulto.reglas, ahora, desfaseMin),
    ...pushSinNoticias(adulto.nombre, adulto.ultimaActividad, adulto.reglas, ahora, desfaseMin),
  ];
  for (const p of pushes) enviados += await mandar(nube, folio, adulto.uidAdulto, p);
  return enviados;
}

export async function revisarTodos(nube: Nube, ahora: Date, desfaseMin: number): Promise<number> {
  let total = 0;
  for (const folio of await nube.folios()) {
    try {
      total += await revisar(nube, folio, ahora, desfaseMin);
    } catch (e) {
      // Una persona con datos raros no detiene los avisos de las demás.
      console.log(`Error con ${folio}: ${e}`);
    }
  }
  return total;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (req.method === 'GET' && url.pathname === '/salud') {
      return Response.json({ ok: true, cuenta: Boolean(env.CUENTA_SERVICIO) });
    }
    if (req.method === 'POST' && url.pathname === '/ahora') {
      let folio: unknown;
      try {
        folio = ((await req.json()) as { folio?: unknown }).folio;
      } catch {
        return Response.json({ error: 'cuerpo inválido' }, { status: 400 });
      }
      if (!folioValido(folio)) return Response.json({ error: 'folio inválido' }, { status: 400 });
      const nube = await NubeGoogle.crear(env.CUENTA_SERVICIO);
      // Solo alertas (lo urgente); medicinas y «sin noticias» van con el cron.
      const enviados = await revisar(nube, folio, new Date(), desfase(env), false);
      return Response.json({ ok: true, enviados });
    }
    return new Response('NANA avisos', { status: 404 });
  },

  async scheduled(_evento: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(
      (async () => {
        const nube = await NubeGoogle.crear(env.CUENTA_SERVICIO);
        const total = await revisarTodos(nube, new Date(), desfase(env));
        if (total) console.log(`Push enviados: ${total}`);
      })(),
    );
  },
};
