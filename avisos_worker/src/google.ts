// Firestore (REST) y FCM HTTP v1 con la cuenta de servicio de Firebase.
// FCM es gratis también en el plan Spark: no hace falta Blaze.
//
// La llave de la cuenta de servicio vive como secreto del Worker
// (wrangler secret put CUENTA_SERVICIO); nunca en el repo.

import type { Alerta, Medicina, ReglasAlerta } from './reglas';
import { reglasDeFabrica } from './reglas';

export interface CuentaServicio {
  client_email: string;
  private_key: string;
  project_id: string;
}

// Lo que index.ts necesita de la nube. Las pruebas usan una versión falsa.
export interface Nube {
  folios(): Promise<string[]>;
  adulto(folio: string): Promise<Adulto | null>;
  alertasSinAtender(folio: string): Promise<Alerta[]>;
  medicinas(folio: string): Promise<Medicina[]>;
  tomadasDesde(folio: string, desde: Date): Promise<Set<string>>;
  uidsFamilia(folio: string): Promise<string[]>;
  tokens(uid: string): Promise<string[]>;
  // true si la clave era nueva (el push no se había mandado).
  apartar(clave: string): Promise<boolean>;
  marcarAlerta(folio: string, id: string): Promise<void>;
  enviar(token: string, titulo: string, cuerpo: string, datos: Record<string, string>): Promise<boolean>;
}

export interface Adulto {
  nombre: string;
  uidAdulto: string | null;
  reglas: ReglasAlerta;
  ultimaActividad: Date | null;
}

// ---------- Valores de Firestore REST ----------

type Valor = Record<string, unknown>;

export function leer(v: Valor | undefined): unknown {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return new Date(String(v.timestampValue));
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) {
    const a = v.arrayValue as { values?: Valor[] };
    return (a.values ?? []).map(leer);
  }
  if ('mapValue' in v) {
    const m = v.mapValue as { fields?: Record<string, Valor> };
    return campos(m.fields);
  }
  return null;
}

export function campos(f: Record<string, Valor> | undefined): Record<string, unknown> {
  const salida: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(f ?? {})) salida[k] = leer(v);
  return salida;
}

// ---------- Token de acceso (JWT firmado con la llave de la cuenta) ----------

function base64url(datos: ArrayBuffer | string): string {
  const bytes = typeof datos === 'string' ? new TextEncoder().encode(datos) : new Uint8Array(datos);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function firmar(pem: string, texto: string): Promise<string> {
  const cuerpo = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(cuerpo), (c) => c.charCodeAt(0));
  const llave = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return base64url(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', llave, new TextEncoder().encode(texto)));
}

export async function tokenDeAcceso(cuenta: CuentaServicio, ahora = Date.now()): Promise<string> {
  const iat = Math.floor(ahora / 1000);
  const encabezado = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const reclamo = base64url(
    JSON.stringify({
      iss: cuenta.client_email,
      scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat,
      exp: iat + 3600,
    }),
  );
  const jwt = `${encabezado}.${reclamo}.${await firmar(cuenta.private_key, `${encabezado}.${reclamo}`)}`;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${jwt}`,
  });
  if (!r.ok) throw new Error(`Google no dio token: ${r.status} ${await r.text()}`);
  return ((await r.json()) as { access_token: string }).access_token;
}

// ---------- La nube real ----------

export class NubeGoogle implements Nube {
  private base: string;
  constructor(private cuenta: CuentaServicio, private token: string) {
    this.base = `https://firestore.googleapis.com/v1/projects/${cuenta.project_id}/databases/(default)/documents`;
  }

  static async crear(json: string): Promise<NubeGoogle> {
    const cuenta = JSON.parse(json) as CuentaServicio;
    return new NubeGoogle(cuenta, await tokenDeAcceso(cuenta));
  }

  private async pedir(url: string, init: RequestInit = {}): Promise<Response> {
    return fetch(url, {
      ...init,
      headers: { Authorization: `Bearer ${this.token}`, 'Content-Type': 'application/json', ...(init.headers ?? {}) },
    });
  }

  private async lista(ruta: string): Promise<{ id: string; datos: Record<string, unknown> }[]> {
    const salida: { id: string; datos: Record<string, unknown> }[] = [];
    let pagina = '';
    do {
      const r = await this.pedir(`${this.base}/${ruta}?pageSize=300${pagina ? `&pageToken=${pagina}` : ''}`);
      if (!r.ok) throw new Error(`Firestore ${ruta}: ${r.status}`);
      const j = (await r.json()) as { documents?: { name: string; fields?: Record<string, Valor> }[]; nextPageToken?: string };
      for (const d of j.documents ?? []) salida.push({ id: d.name.split('/').pop()!, datos: campos(d.fields) });
      pagina = j.nextPageToken ?? '';
    } while (pagina);
    return salida;
  }

  async folios() {
    return (await this.lista('adultos')).map((d) => d.id);
  }

  async adulto(folio: string): Promise<Adulto | null> {
    const r = await this.pedir(`${this.base}/adultos/${folio}`);
    if (r.status === 404) return null;
    if (!r.ok) throw new Error(`Firestore adulto: ${r.status}`);
    const d = campos(((await r.json()) as { fields?: Record<string, Valor> }).fields);
    const reglas = (d.reglasAlerta ?? {}) as Partial<ReglasAlerta>;
    return {
      nombre: String(d.nombre ?? ''),
      uidAdulto: (d.uidAdulto as string | null) ?? null,
      reglas: {
        medicina: reglas.medicina ?? reglasDeFabrica.medicina,
        sinNoticias: reglas.sinNoticias ?? reglasDeFabrica.sinNoticias,
        horasSinNoticias: reglas.horasSinNoticias ?? reglasDeFabrica.horasSinNoticias,
      },
      ultimaActividad: (d.ultimaActividad as Date | null) ?? null,
    };
  }

  private async consulta(folio: string, coleccion: string, filtro: object) {
    const r = await this.pedir(`${this.base}/adultos/${folio}:runQuery`, {
      method: 'POST',
      body: JSON.stringify({ structuredQuery: { from: [{ collectionId: coleccion }], where: filtro } }),
    });
    if (!r.ok) throw new Error(`Firestore ${coleccion}: ${r.status}`);
    const filas = (await r.json()) as { document?: { name: string; fields?: Record<string, Valor> } }[];
    return filas
      .filter((f) => f.document)
      .map((f) => ({ id: f.document!.name.split('/').pop()!, datos: campos(f.document!.fields) }));
  }

  // Solo las que no se han atendido (las viejas no se vuelven a leer).
  async alertasSinAtender(folio: string): Promise<Alerta[]> {
    const filtro = { fieldFilter: { field: { fieldPath: 'atendida' }, op: 'EQUAL', value: { booleanValue: false } } };
    return (await this.consulta(folio, 'alertas', filtro))
      .map((d) => ({
        id: d.id,
        tipo: String(d.datos.tipo ?? 'pide_ayuda'),
        como: d.datos.como as string | undefined,
        texto: d.datos.texto as string | undefined,
        fecha: (d.datos.fecha as Date) ?? new Date(0),
        atendida: false,
        pushEnviada: d.datos.pushEnviada === true,
      }));
  }

  async medicinas(folio: string): Promise<Medicina[]> {
    return (await this.lista(`adultos/${folio}/medicamentos`)).map((d) => ({
      id: d.id,
      nombre: String(d.datos.nombre ?? ''),
      hora: String(d.datos.hora ?? '00:00'),
      ventanaMin: Number(d.datos.ventanaMin ?? 30),
    }));
  }

  async tomadasDesde(folio: string, desde: Date): Promise<Set<string>> {
    const filtro = {
      fieldFilter: { field: { fieldPath: 'fecha' }, op: 'GREATER_THAN_OR_EQUAL', value: { timestampValue: desde.toISOString() } },
    };
    const ids = new Set<string>();
    for (const d of await this.consulta(folio, 'registros', filtro)) {
      if (typeof d.datos.idMedicamento === 'string') ids.add(d.datos.idMedicamento);
    }
    return ids;
  }

  async uidsFamilia(folio: string) {
    return (await this.lista(`adultos/${folio}/cuidadores`)).map((d) => d.id);
  }

  async tokens(uid: string): Promise<string[]> {
    const r = await this.pedir(`${this.base}/usuarios/${uid}`);
    if (!r.ok) return [];
    const d = campos(((await r.json()) as { fields?: Record<string, Valor> }).fields);
    return Array.isArray(d.tokensPush) ? d.tokensPush.filter((t): t is string => typeof t === 'string') : [];
  }

  // Crea push_enviados/{clave} solo si no existe: si dos crons chocan, uno gana.
  async apartar(clave: string): Promise<boolean> {
    const r = await this.pedir(`${this.base}/push_enviados?documentId=${encodeURIComponent(clave)}`, {
      method: 'POST',
      body: JSON.stringify({ fields: { fecha: { timestampValue: new Date().toISOString() } } }),
    });
    if (r.status === 409) return false;
    if (!r.ok) throw new Error(`Firestore apartar: ${r.status}`);
    return true;
  }

  async marcarAlerta(folio: string, id: string) {
    await this.pedir(`${this.base}/adultos/${folio}/alertas/${id}?updateMask.fieldPaths=pushEnviada`, {
      method: 'PATCH',
      body: JSON.stringify({ fields: { pushEnviada: { booleanValue: true } } }),
    });
  }

  async enviar(token: string, titulo: string, cuerpo: string, datos: Record<string, string>) {
    const r = await this.pedir(`https://fcm.googleapis.com/v1/projects/${this.cuenta.project_id}/messages:send`, {
      method: 'POST',
      body: JSON.stringify({
        message: {
          token,
          notification: { title: titulo, body: cuerpo },
          data: datos,
          android: {
            priority: 'HIGH',
            // El mismo canal que ya usa la app (core/avisos.dart).
            notification: { channel_id: 'alertas_familia', sound: 'default' },
          },
          apns: { payload: { aps: { sound: 'default', 'interruption-level': 'time-sensitive' } } },
        },
      }),
    });
    if (!r.ok) console.log(`FCM ${r.status}: ${await r.text()}`);
    return r.ok;
  }
}
