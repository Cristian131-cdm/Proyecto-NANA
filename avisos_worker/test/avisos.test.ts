import { describe, expect, it } from 'vitest';

import { leer, type Adulto, type Nube } from '../src/google';
import { revisar, revisarTodos } from '../src/index';
import {
  diaLocal,
  inicioDelDia,
  pushDeAlertas,
  pushDeMedicinas,
  pushSinNoticias,
  reglasDeFabrica,
  type Alerta,
  type Medicina,
} from '../src/reglas';

const MX = -360;
// 25 nov 2026 a las [h]:[m] en México = +6 h en UTC.
const mx = (h: number, m = 0) => new Date(Date.UTC(2026, 10, 25, h + 6, m));
const losartan: Medicina = { id: 'm1', nombre: 'Losartán', hora: '08:00', ventanaMin: 30 };

describe('reglas', () => {
  it('día y medianoche en hora de México', () => {
    expect(diaLocal(mx(23, 30), MX)).toBe('20261125');
    expect(inicioDelDia(mx(10), MX).toISOString()).toBe('2026-11-25T06:00:00.000Z');
  });

  it('pidió ayuda: push a la familia con palabras fijas', () => {
    const a: Alerta = { id: 'a1', tipo: 'pide_ayuda', como: 'voz', fecha: mx(10, 5), atendida: false };
    const [p] = pushDeAlertas('Rosa', [a], mx(10, 6), MX);
    expect(p.para).toBe('familia');
    expect(p.titulo).toBe('Rosa necesita ayuda');
    expect(p.cuerpo).toBe('La pidió con la voz a las 10:05. Abre NANA para llamarle.');
  });

  it('no repite alertas ya enviadas, atendidas o viejas', () => {
    const base = { tipo: 'pide_ayuda', atendida: false };
    const alertas: Alerta[] = [
      { ...base, id: 'enviada', fecha: mx(10), pushEnviada: true },
      { ...base, id: 'atendida', fecha: mx(10), atendida: true },
      { ...base, id: 'vieja', fecha: mx(6) },
    ];
    expect(pushDeAlertas('Rosa', alertas, mx(10, 1), MX)).toEqual([]);
  });

  it('medicina sin marcar: avisa a la familia a la hora + 2 ventanas', () => {
    const r = reglasDeFabrica;
    expect(pushDeMedicinas('Rosa', [losartan], new Set(), r, mx(8, 59), MX)).toEqual([]);
    const [p] = pushDeMedicinas('Rosa', [losartan], new Set(), r, mx(9, 0), MX);
    expect(p.titulo).toBe('Rosa no ha marcado su Losartán');
    expect(p.clave).toBe('med_m1_20261125');
    expect(pushDeMedicinas('Rosa', [losartan], new Set(['m1']), r, mx(9, 0), MX)).toEqual([]);
    expect(pushDeMedicinas('Rosa', [losartan], new Set(), { ...r, medicina: false }, mx(9, 0), MX)).toEqual([]);
    expect(pushDeMedicinas('Rosa', [losartan], new Set(), r, mx(9, 30), MX)).toEqual([]);
  });

  it('medicina que ya terminó: no avisa; el último día sí', () => {
    const r = reglasDeFabrica;
    // La app guarda «hasta» como medianoche local (México) del último día.
    const fin = new Date(Date.UTC(2026, 10, 25, 6, 0));
    const conFin = { ...losartan, hasta: fin };
    expect(pushDeMedicinas('Rosa', [conFin], new Set(), r, mx(9, 0), MX)).toHaveLength(1);
    const ayer = { ...losartan, hasta: new Date(Date.UTC(2026, 10, 24, 6, 0)) };
    expect(pushDeMedicinas('Rosa', [ayer], new Set(), r, mx(9, 0), MX)).toEqual([]);
  });

  it('toma que empieza mañana: hoy no avisa', () => {
    const manana = new Date(Date.UTC(2026, 10, 26, 6, 0)); // medianoche local del 26
    const nueva = { ...losartan, desde: manana };
    expect(pushDeMedicinas('Rosa', [nueva], new Set(), reglasDeFabrica, mx(9, 0), MX)).toEqual([]);
    const hoy = { ...losartan, desde: new Date(Date.UTC(2026, 10, 25, 6, 0)) };
    expect(pushDeMedicinas('Rosa', [hoy], new Set(), reglasDeFabrica, mx(9, 0), MX)).toHaveLength(1);
  });

  it('sin noticias: solo si pasaron las horas y la regla está prendida', () => {
    expect(pushSinNoticias('Rosa', mx(1), reglasDeFabrica, mx(10), MX)).toEqual([]);
    const [p] = pushSinNoticias('Rosa', mx(1), { ...reglasDeFabrica, horasSinNoticias: 6 }, mx(10), MX);
    expect(p.cuerpo).toContain('9 horas');
  });

  it('lee valores de Firestore REST', () => {
    expect(leer({ stringValue: 'Rosa' })).toBe('Rosa');
    expect(leer({ integerValue: '30' })).toBe(30);
    expect(leer({ mapValue: { fields: { medicina: { booleanValue: false } } } })).toEqual({ medicina: false });
    expect(leer({ arrayValue: { values: [{ stringValue: 't1' }] } })).toEqual(['t1']);
  });
});

class NubeFalsa implements Nube {
  apartadas = new Set<string>();
  enviados: { token: string; titulo: string }[] = [];
  marcadas: string[] = [];
  alertas: Alerta[] = [];
  meds: Medicina[] = [losartan];
  tomadas = new Set<string>();
  persona: Adulto = { nombre: 'Rosa', uidAdulto: 'uAdulto', reglas: reglasDeFabrica, ultimaActividad: null };

  async folios() { return ['F1']; }
  async adulto() { return this.persona; }
  async alertasSinAtender() { return this.alertas.filter((a) => !this.marcadas.includes(a.id)).map((a) => ({ ...a })); }
  async medicinas() { return this.meds; }
  async tomadasDesde() { return this.tomadas; }
  async uidsFamilia() { return ['uHija', 'uNieto']; }
  async tokens(uid: string) { return uid === 'uHija' ? ['tHija1', 'tHija2'] : uid === 'uNieto' ? ['tNieto'] : ['tAdulto']; }
  async apartar(clave: string) {
    if (this.apartadas.has(clave)) return false;
    this.apartadas.add(clave);
    return true;
  }
  async marcarAlerta(_folio: string, id: string) { this.marcadas.push(id); }
  async enviar(token: string, titulo: string) {
    this.enviados.push({ token, titulo });
    return true;
  }
}

describe('revisar', () => {
  it('«Necesito ayuda» llega a todos los celulares de la familia, una sola vez', async () => {
    const nube = new NubeFalsa();
    nube.alertas = [{ id: 'a1', tipo: 'pide_ayuda', fecha: mx(10), atendida: false }];
    expect(await revisar(nube, 'F1', mx(10, 0), MX, false)).toBe(3);
    expect(nube.enviados.map((e) => e.token)).toEqual(['tHija1', 'tHija2', 'tNieto']);
    expect(nube.marcadas).toEqual(['a1']);
    // El cron llega después: ya no la repite.
    expect(await revisarTodos(nube, mx(10, 1), MX)).toBe(0);
  });

  it('el cron avisa la medicina olvidada una vez al día', async () => {
    const nube = new NubeFalsa();
    expect(await revisarTodos(nube, mx(9, 0), MX)).toBe(3);
    expect(await revisarTodos(nube, mx(9, 1), MX)).toBe(0);
    expect(nube.enviados[0].titulo).toBe('Rosa no ha marcado su Losartán');
  });

  it('si ya se la tomó, nadie recibe nada', async () => {
    const nube = new NubeFalsa();
    nube.tomadas = new Set(['m1']);
    expect(await revisarTodos(nube, mx(9, 0), MX)).toBe(0);
  });
});
