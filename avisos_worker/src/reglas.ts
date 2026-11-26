// Qué push mandar y con qué palabras. Sin red ni Firestore: se prueba solo.
//
// Regla de arquitectura de NANA: las alertas críticas son código fijo, nunca
// un modelo. Por eso los textos de aquí son plantillas con la voz de NANA.

export interface Medicina {
  id: string;
  nombre: string;
  hora: string; // 'HH:mm'
  ventanaMin: number;
}

export interface ReglasAlerta {
  medicina: boolean;
  sinNoticias: boolean;
  horasSinNoticias: number;
}

export interface Alerta {
  id: string;
  tipo: string; // 'pide_ayuda' | 'frase'
  como?: string; // 'boton' | 'voz' | 'sin_respuesta'
  texto?: string;
  fecha: Date;
  atendida: boolean;
  pushEnviada?: boolean;
}

export interface Push {
  // A quién: 'familia' = encargado, suplente y familiares.
  para: 'familia' | 'adulto';
  titulo: string;
  cuerpo: string;
  // Para que la app sepa qué abrir al tocarla.
  datos: Record<string, string>;
  // Id para no mandarlo dos veces (lo guarda index.ts en Firestore).
  clave: string;
}

export const reglasDeFabrica: ReglasAlerta = {
  medicina: true,
  sinNoticias: true,
  horasSinNoticias: 12,
};

// México centro no tiene horario de verano desde 2022: UTC-6 fijo.
export function horaLocal(utc: Date, desfaseMin: number): Date {
  return new Date(utc.getTime() + desfaseMin * 60_000);
}

// 'AAAAMMDD' del día local (para las claves de "ya lo mandé").
export function diaLocal(utc: Date, desfaseMin: number): string {
  const l = horaLocal(utc, desfaseMin);
  return `${l.getUTCFullYear()}${String(l.getUTCMonth() + 1).padStart(2, '0')}${String(l.getUTCDate()).padStart(2, '0')}`;
}

// Inicio del día local, en UTC (para pedir los registros de hoy).
export function inicioDelDia(utc: Date, desfaseMin: number): Date {
  const l = horaLocal(utc, desfaseMin);
  const medianocheLocal = Date.UTC(l.getUTCFullYear(), l.getUTCMonth(), l.getUTCDate());
  return new Date(medianocheLocal - desfaseMin * 60_000);
}

// Minuto del día local en que vence algo que empieza a [hora] y espera [extra].
function minutoDe(hora: string, extra: number): number {
  const [h, m] = hora.split(':').map(Number);
  return h * 60 + m + extra;
}

export function textoAlerta(nombre: string, a: Alerta, hora: string): { titulo: string; cuerpo: string } {
  if (a.tipo === 'frase') {
    return { titulo: `${nombre} dijo: "${a.texto ?? ''}"`, cuerpo: `A las ${hora}. Abre NANA para llamarle.` };
  }
  if (a.como === 'sin_respuesta') {
    return {
      titulo: `${nombre} necesita ayuda y no contesta`,
      cuerpo: `Dijo que necesitaba ayuda a las ${hora} y después no contestó. Llámale ya.`,
    };
  }
  const como = a.como === 'voz' ? 'La pidió con la voz' : 'Tocó el botón de ayuda';
  return { titulo: `${nombre} necesita ayuda`, cuerpo: `${como} a las ${hora}. Abre NANA para llamarle.` };
}

function horaCorta(fecha: Date, desfaseMin: number): string {
  const l = horaLocal(fecha, desfaseMin);
  return `${l.getUTCHours()}:${String(l.getUTCMinutes()).padStart(2, '0')}`;
}

// Alertas nuevas (pidió ayuda o dijo algo) que todavía no tienen push.
// Solo las de las últimas 2 horas: una vieja ya no sirve de aviso.
export function pushDeAlertas(nombre: string, alertas: Alerta[], ahora: Date, desfaseMin: number): Push[] {
  const limite = ahora.getTime() - 2 * 60 * 60_000;
  return alertas
    .filter((a) => !a.atendida && !a.pushEnviada && a.fecha.getTime() >= limite)
    .map((a) => ({
      para: 'familia' as const,
      ...textoAlerta(nombre, a, horaCorta(a.fecha, desfaseMin)),
      datos: { tipo: 'alerta', alerta: a.id },
      clave: `alerta_${a.id}`,
    }));
}

// Medicinas que no se marcaron: el celular del adulto ya le preguntó a la
// hora + ventana (alarma local). Si a la hora + 2 ventanas sigue sin marcar,
// NANA le avisa a la familia (si la regla «medicina» está prendida).
export function pushDeMedicinas(
  nombre: string,
  meds: Medicina[],
  tomadasHoy: Set<string>,
  reglas: ReglasAlerta,
  ahora: Date,
  desfaseMin: number,
): Push[] {
  if (!reglas.medicina) return [];
  const l = horaLocal(ahora, desfaseMin);
  const minutoAhora = l.getUTCHours() * 60 + l.getUTCMinutes();
  const dia = diaLocal(ahora, desfaseMin);
  const salida: Push[] = [];
  for (const m of meds) {
    if (tomadasHoy.has(m.id)) continue;
    const vence = minutoDe(m.hora, 2 * Math.max(m.ventanaMin, 5));
    // Se revisa cada minuto; con 10 de margen no se pierde si un cron falla.
    if (minutoAhora < vence || minutoAhora > vence + 10) continue;
    salida.push({
      para: 'familia',
      titulo: `${nombre} no ha marcado su ${m.nombre}`,
      cuerpo: `Le tocaba a las ${m.hora}. NANA ya le preguntó y no contestó. ¿Le llamas?`,
      datos: { tipo: 'medicina', medicina: m.id },
      clave: `med_${m.id}_${dia}`,
    });
  }
  return salida;
}

// Sin noticias: nada registrado en [horasSinNoticias] horas. Una vez al día.
export function pushSinNoticias(
  nombre: string,
  ultimaActividad: Date | null,
  reglas: ReglasAlerta,
  ahora: Date,
  desfaseMin: number,
): Push[] {
  if (!reglas.sinNoticias || !ultimaActividad) return [];
  const horas = (ahora.getTime() - ultimaActividad.getTime()) / 3_600_000;
  if (horas < reglas.horasSinNoticias) return [];
  return [
    {
      para: 'familia',
      titulo: `Hace rato que no sabemos de ${nombre}`,
      cuerpo: `Nada en NANA desde hace ${Math.floor(horas)} horas. ¿Le llamas para ver cómo está?`,
      datos: { tipo: 'sin_noticias' },
      clave: `sin_noticias_${diaLocal(ahora, desfaseMin)}`,
    },
  ];
}
