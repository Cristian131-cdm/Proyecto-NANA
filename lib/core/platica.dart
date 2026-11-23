import 'package:flutter/material.dart';

import '../models/actividad.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/caritas_animo.dart';
import 'agente.dart';
import 'dia.dart';
import 'semana.dart';
import 'servicios.dart';
import 'voz.dart';

// Lo que NANA contesta en «Platicando con NANA», SIN IA: listas fijas y los
// datos que ya tiene la app. Son funciones puras para probarlas. Cuando
// exista el agente, se conecta en el mismo lugar (el [Responder] de la
// pantalla) y estas respuestas quedan como respaldo: ver _abrirPlatica en
// screens/panel_adulto.dart.

enum AccionPlatica {
  ninguna,
  terminar, // cierra la plática
  ayuda, // cierra y abre «Necesito ayuda» (con su confirmación)
  familia, // cierra y abre Mi familia
  frase, // le cuenta [frase] a la familia y sigue platicando
}

class RespuestaPlatica {
  final String texto;
  final AccionPlatica accion;
  final String? frase;
  // true: la resolvió una regla de la app (ayuda, médica, familia, la hora…)
  // y no se le pregunta al agente. false: es plática; si hay agente, contesta
  // él y esta respuesta queda de respaldo.
  final bool fija;

  const RespuestaPlatica(
    this.texto, {
    this.accion = AccionPlatica.ninguna,
    this.frase,
    this.fija = true,
  });
}

/// Lo que contestó el agente, como respuesta de la plática. Sus acciones
/// abren lo mismo que las reglas de la app.
RespuestaPlatica respuestaDelAgente(RespuestaAgente r) => RespuestaPlatica(
  r.texto,
  accion: switch (r.accion) {
    'abrir_ayuda' => AccionPlatica.ayuda,
    'abrir_familia' => AccionPlatica.familia,
    _ => AccionPlatica.ninguna,
  },
  fija: false,
);

typedef Responder = Future<RespuestaPlatica> Function(String oido);

// Lo que la app entiende al hablar (lo usan «Hablar con NANA» y la plática).
// Las preocupantes van primero, para que "ya tomé mi medicina pero me siento
// mal" cuente como "me siento mal".
const comandosAdulto = <(String, List<String>)>[
  // Las urgencias abren «Voy a avisar a tu familia» con cuenta regresiva.
  // Van aquí y no solo en el agente (agente/nana_agente/reglas.py, URGENCIA)
  // para que funcionen sin la laptop. test/urgencias_test.dart revisa que
  // ninguna de las del agente falte aquí.
  (
    'Necesito ayuda',
    [
      'ayuda',
      'ayudame',
      'ayudenme',
      'auxilio',
      'socorro',
      'emergencia',
      'ambulancia',
      'me cai',
      'me resbale',
      'no me puedo levantar',
      'no puedo levantarme',
      'no me puedo mover',
      'me pegue en la cabeza',
      'dolor en el pecho',
      'me duele el pecho',
      'no puedo respirar',
      'me estoy ahogando',
      'me falta el aire',
      'me desmaye',
      'me voy a desmayar',
      'estoy sangrando',
      'me siento muy mal',
      'muy mareada',
      'muy mareado',
      'no siento las piernas',
      'no siento el brazo',
      'huele a gas',
    ],
  ),
  (
    'Me siento mal',
    [
      'me siento mal',
      'me duele',
      'me siento enferma',
      'me siento enfermo',
      'estoy mareada',
      'estoy mareado',
    ],
  ),
  (
    'familia',
    [
      'llama',
      'llamar',
      'marca',
      'marcale',
      'hablale',
      'hablar con',
      'mi familia',
      'mi hija',
      'mi hijo',
      'mi nieta',
      'mi nieto',
      'mi esposo',
      'mi esposa',
    ],
  ),
  (
    '¿Qué sigue hoy?',
    ['que sigue', 'que me toca', 'que tengo hoy', 'que hay hoy'],
  ),
  (
    'Ya tomé mi medicina',
    [
      'ya me la tome',
      'ya tome mi medicina',
      'ya me tome',
      'ya tome la pastilla',
      'ya tome',
    ],
  ),
  ('Ya comí', ['ya comi', 'ya desayune', 'ya cene']),
];

const frasesTerminar = [
  'gracias nana',
  'adios',
  'eso es todo',
  'es todo',
  'ya es todo',
  'hasta luego',
  'nada mas',
  'ya termine',
  'terminar',
  // Agregadas el 2026-11-23 (cómo se despide la gente de verdad). No va
  // "buenas noches": también se usa para saludar al empezar. Ni "ya me voy"
  // a secas: "ya me voy a tomar la pastilla" cerraría la plática.
  'nos vemos',
  'chao',
  'bye',
  'luego platicamos',
  'al rato platicamos',
  'hasta manana',
  'me voy a dormir',
  'ya me tengo que ir',
  'ya no quiero platicar',
  'cierra',
];

// "me voy" solo cuenta al final de la frase: "bueno, ya me voy, NANA" se
// despide, pero "ya me voy a tomar la pastilla" sigue la plática.
const _despedidasAlFinal = ['me voy', 'ya me voy', 'me retiro'];

bool esDespedida(String oido) {
  if (_dice(oido, frasesTerminar)) return true;
  var t = normalizar(oido);
  for (final cola in [' nana', ' adios', ' gracias']) {
    if (t.endsWith(cola)) t = t.substring(0, t.length - cola.length).trim();
  }
  return _despedidasAlFinal.any((f) => t == f || t.endsWith(' $f'));
}

// Preguntas de salud: NANA no aconseja (Charter: solo registra, recuerda y
// alerta).
const _preguntaMedicaAdulto = [
  'que medicina',
  'que pastilla',
  'cuantas pastillas',
  'cuantas me tomo',
  'puedo tomar',
  'debo tomar',
  'dejo de tomar',
  'dejar de tomar',
  'que me tomo',
  'que tomo para',
  'que es bueno para',
  'dosis',
];

const _charlaAdulto = <(String, List<String>)>[
  ('quien', ['quien eres', 'como te llamas', 'que eres']),
  ('como_estas', ['como estas', 'como te va', 'como andas', 'como amaneciste']),
  ('hora', ['que hora es', 'que horas son']),
  ('fecha', ['que dia es', 'que fecha es', 'a cuantos estamos']),
  (
    'triste',
    [
      'no estoy bien',
      'no me siento bien',
      'triste',
      'me siento sola',
      'me siento solo',
      'estoy sola',
      'estoy solo',
    ],
  ),
  (
    'bien',
    [
      'estoy bien',
      'me siento bien',
      'estoy contenta',
      'estoy contento',
      'muy bien',
    ],
  ),
  ('gracias', ['gracias']),
  (
    'saludo',
    ['hola', 'buenos dias', 'buenas tardes', 'buenas noches', 'que tal'],
  ),
];

const ayudaParaDecir =
    'Puedes decirme: ¿qué sigue hoy?, ya comí, o llama a mi familia.';

String saludoDeLaHora(DateTime ahora) => ahora.hour < 12
    ? 'Buenos días'
    : ahora.hour < 19
    ? 'Buenas tardes'
    : 'Buenas noches';

// 'Son las 8:05' / 'Es la 1:30 pm'
String decirHora(DateTime ahora) {
  final h = horaCorta(TimeOfDay.fromDateTime(ahora));
  return ahora.hour % 12 == 1 ? 'Es la $h.' : 'Son las $h.';
}

String decirFecha(DateTime ahora) =>
    'Hoy es ${nombresDias[ahora.weekday - 1]} ${fechaLarga(ahora)}.';

bool _dice(String texto, List<String> frases) =>
    entender(texto, [(true, frases)]) == true;

RespuestaPlatica respuestaAdulto(
  String oido, {
  required String nombre,
  required String Function() queSigue,
  required DateTime ahora,
}) {
  if (esDespedida(oido)) {
    return RespuestaPlatica(
      'Aquí estoy cuando me necesites, $nombre.',
      accion: AccionPlatica.terminar,
    );
  }
  final comando = entender(oido, comandosAdulto);
  if (comando == 'Necesito ayuda') {
    return const RespuestaPlatica(
      'Te escucho. Voy a avisarle a tu familia.',
      accion: AccionPlatica.ayuda,
    );
  }
  if (comando == 'Me siento mal') {
    return RespuestaPlatica(
      'Lo siento, $nombre. Se lo cuento a tu familia.',
      accion: AccionPlatica.frase,
      frase: 'Me siento mal',
    );
  }
  if (_dice(oido, _preguntaMedicaAdulto)) {
    return const RespuestaPlatica(
      'Eso pregúntaselo a tu médico o a tu familia. Yo te recuerdo lo que '
      'ellos te dejaron anotado.',
    );
  }
  switch (comando) {
    case 'familia':
      return const RespuestaPlatica(
        'Vamos con tu familia.',
        accion: AccionPlatica.familia,
      );
    case '¿Qué sigue hoy?':
      return RespuestaPlatica(queSigue());
    case 'Ya tomé mi medicina':
      return const RespuestaPlatica(
        'Muy bien. Se lo cuento a tu familia.',
        accion: AccionPlatica.frase,
        frase: 'Ya tomé mi medicina',
      );
    case 'Ya comí':
      return const RespuestaPlatica(
        'Qué bueno. Ya lo anoté.',
        accion: AccionPlatica.frase,
        frase: 'Ya comí',
      );
  }
  return switch (entender(oido, _charlaAdulto)) {
    'quien' => const RespuestaPlatica(
      'Soy NANA, tu compañera. Te recuerdo las cosas de tu día y le aviso a '
      'tu familia si lo necesitas.',
      fija: false,
    ),
    'como_estas' => const RespuestaPlatica(
      'Muy bien, gracias por preguntar. ¿Y tú cómo te sientes?',
      fija: false,
    ),
    'hora' => RespuestaPlatica(decirHora(ahora)),
    'fecha' => RespuestaPlatica(decirFecha(ahora)),
    'triste' => const RespuestaPlatica(
      'Aquí estoy contigo. Si quieres hablar con tu familia, dime: llama a '
      'mi familia.',
      fija: false,
    ),
    'bien' => const RespuestaPlatica('Qué gusto me da.', fija: false),
    'gracias' => const RespuestaPlatica('De nada. Aquí estoy.', fija: false),
    'saludo' => RespuestaPlatica(
      '${saludoDeLaHora(ahora)}, $nombre.',
      fija: false,
    ),
    _ => const RespuestaPlatica(
      'Todavía no entiendo eso. $ayudaParaDecir',
      fija: false,
    ),
  };
}

// ---------- Pregúntale a NANA (vista del encargado) ----------

// Lo que el encargado puede preguntar se contesta con los mismos datos que
// ya ve en sus pestañas. Solo datos, sin interpretar ni aconsejar.
class DatosEncargado {
  final String nombre;
  final List<Medicamento> meds;
  final List<Rutina> rutinas;
  final List<Registro> hoy;
  final List<Registro> semana; // últimos 7 días, hoy incluido
  final List<Alerta> alertas; // sin atender
  final DateTime ahora;

  const DatosEncargado({
    required this.nombre,
    required this.meds,
    required this.rutinas,
    required this.hoy,
    required this.semana,
    required this.alertas,
    required this.ahora,
  });
}

Future<DatosEncargado> cargarDatosEncargado(String folio, String nombre) async {
  final ahora = Servicios.reloj();
  final repo = Servicios.repo;
  final desde = DateUtils.dateOnly(ahora).subtract(const Duration(days: 6));
  final r = await Future.wait([
    repo.medicamentos(folio).first,
    repo.rutinas(folio).first,
    repo.registrosDeHoy(folio).first,
    repo.registrosDesde(folio, desde).first,
    repo.alertasSinAtender(folio).first,
  ]);
  return DatosEncargado(
    nombre: nombre,
    meds: r[0] as List<Medicamento>,
    rutinas: r[1] as List<Rutina>,
    hoy: r[2] as List<Registro>,
    semana: r[3] as List<Registro>,
    alertas: r[4] as List<Alerta>,
    ahora: ahora,
  );
}

const _preguntasEncargado = <(String, List<String>)>[
  (
    'medica',
    [
      'dosis',
      'le subo',
      'le bajo',
      'le aumento',
      'le quito',
      'deja de tomar',
      'dejar de tomar',
      'que le doy',
      'que medicina le',
      'que pastilla le',
      'puede tomar',
      'es grave',
      'esta enferma',
      'esta enfermo',
    ],
  ),
  ('semana', ['semana', 'estos dias', 'ultimos dias']),
  (
    'medicina',
    [
      'pastilla',
      'pastillas',
      'medicina',
      'medicinas',
      'medicamento',
      'medicamentos',
    ],
  ),
  ('animo', ['como se siente', 'como se sintio', 'animo', 'de humor']),
  ('alertas', ['alerta', 'alertas', 'aviso', 'avisos', 'pidio ayuda']),
  ('sigue', ['que sigue', 'que le toca', 'que tiene hoy', 'que falta']),
  (
    'hoy',
    ['como va', 'como esta', 'como le va', 'como sigue', 'hoy', 'que ha hecho'],
  ),
];

const ayudaEncargado =
    'Puedes preguntarme: ¿cómo va hoy?, ¿ya se tomó la pastilla?, o ¿cómo '
    'le fue esta semana?';

List<Actividad> _diaDe(DatosEncargado d) => diaDelAdulto(
  meds: d.meds,
  hoy: d.hoy,
  otras: rutinasDeHoy(d.rutinas, d.ahora),
  ahora: d.ahora,
);

String _lista(List<String> cosas) => cosas.length <= 1
    ? cosas.join()
    : '${cosas.sublist(0, cosas.length - 1).join(', ')} y ${cosas.last}';

bool _tomo(Medicamento m, List<Registro> hoy) =>
    hoy.any((r) => r.tipo == TipoActividad.medicina && r.idMedicamento == m.id);

String _medicinasDeHoy(DatosEncargado d) {
  if (d.meds.isEmpty) return '${d.nombre} no tiene medicinas registradas.';
  final tomadas = [
    for (final m in d.meds)
      if (_tomo(m, d.hoy)) m.nombre,
  ];
  final faltan = sinConfirmar(meds: d.meds, hoy: d.hoy, ahora: d.ahora);
  final despues = [
    for (final m in d.meds)
      if (!_tomo(m, d.hoy) && !faltan.contains(m))
        '${m.nombre} a las ${horaCorta(m.hora)}',
  ];
  return [
    if (tomadas.isNotEmpty) 'Hoy ya tomó ${_lista(tomadas)}.',
    if (faltan.isNotEmpty)
      'Falta confirmar ${_lista([for (final m in faltan) m.nombre])}.',
    if (despues.isNotEmpty) 'Le toca más tarde: ${_lista(despues)}.',
  ].join(' ');
}

String _animoDeHoy(DatosEncargado d) {
  final animos = d.hoy.where((r) => r.tipo == TipoActividad.animo).toList();
  if (animos.isEmpty) return 'Hoy ${d.nombre} todavía no dice cómo se siente.';
  final i = animos.last.valor ?? 2;
  return 'Hoy ${d.nombre} dijo que se siente '
      '${CaritasAnimo.etiquetas[i.clamp(0, 4)].toLowerCase()}, a las '
      '${horaDe(animos.last.fecha)}.';
}

RespuestaPlatica respuestaEncargado(String oido, DatosEncargado d) {
  if (esDespedida(oido)) {
    return const RespuestaPlatica(
      'Listo. Aquí estoy cuando me necesites.',
      accion: AccionPlatica.terminar,
    );
  }
  switch (entender(oido, _preguntasEncargado)) {
    case 'medica':
      return const RespuestaPlatica(
        'Eso lo decide su médico. NANA solo registra, recuerda y alerta.',
      );
    case 'semana':
      final dias = semana(
        meds: d.meds,
        rutinas: d.rutinas,
        registros: d.semana,
        hoy: d.ahora,
      );
      final t = TotalesSemana(dias);
      return RespuestaPlatica(
        [
          t.posibles == 0
              ? 'En los últimos 7 días ${d.nombre} no tuvo medicinas registradas.'
              : 'En los últimos 7 días ${d.nombre} tomó ${t.tomas} de '
                    '${t.posibles} medicinas.',
          if (t.faltas.isNotEmpty) 'Faltó alguna el ${_lista(t.faltas)}.',
          if (t.mal.isNotEmpty)
            'Dijo sentirse mal el ${_lista([for (final x in t.mal) x.nombre])}.',
        ].join(' '),
      );
    case 'medicina':
      return RespuestaPlatica(_medicinasDeHoy(d));
    case 'animo':
      return RespuestaPlatica(_animoDeHoy(d));
    case 'alertas':
      final n = d.alertas.length;
      return RespuestaPlatica(
        n == 0
            ? 'No hay alertas sin atender.'
            : n == 1
            ? 'Hay 1 alerta sin atender. Está en Inicio.'
            : 'Hay $n alertas sin atender. Están en Inicio.',
      );
    case 'sigue':
      final siguiente = _diaDe(d)
          .where((a) => a.estado != EstadoActividad.hecha)
          .firstOrNull;
      return RespuestaPlatica(
        siguiente == null
            ? '${d.nombre} ya hizo todo lo de hoy.'
            : 'Lo que sigue: ${siguiente.titulo}, a las ${siguiente.hora}.',
      );
    case 'hoy':
      final dia = _diaDe(d);
      final hechas = dia.where((a) => a.estado == EstadoActividad.hecha).length;
      return RespuestaPlatica(
        [
          'Hoy ${d.nombre} lleva $hechas de ${dia.length}.',
          if (d.meds.isNotEmpty) _medicinasDeHoy(d),
          _animoDeHoy(d),
        ].join(' '),
      );
  }
  return const RespuestaPlatica('Todavía no sé contestar eso. $ayudaEncargado');
}
