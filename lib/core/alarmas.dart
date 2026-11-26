import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicamento.dart';
import 'dia.dart';

// Alarma diaria de cada medicina en el celular del adulto. La programa el
// sistema, así que suena aunque NANA esté cerrada.
abstract class Alarmas {
  Future<void> iniciar(void Function(String idMedicamento) alTocar);
  Future<void> programar(String nombreAdulto, List<Medicamento> meds);

  // «Ya se pasó»: al terminar la ventana de cada medicina que todavía no se
  // toma hoy, NANA vuelve a preguntar (una sola vez). Las ya tomadas se quitan.
  Future<void> programarPasadas(
    String nombreAdulto,
    List<Medicamento> meds,
    Set<String> tomadasHoy,
  );

  // "Al rato": la misma alarma suena otra vez dentro de [en] (una sola vez).
  Future<void> posponer(String idMedicamento, String texto, Duration en);

  // Si la app se abrió tocando una alarma, el id de esa medicina.
  String? get abiertaDesde;
}

String textoAlarma(String nombre, Medicamento m) =>
    '$nombre, son las ${horaCorta(m.hora)}. '
    'Te toca tu ${m.nombre} de ${m.dosis}.';

// Id estable y positivo para el sistema a partir del id de Firestore (FNV-1a).
int idNotificacion(String idMedicamento) {
  var h = 0x811c9dc5;
  for (final c in idMedicamento.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h & 0x7fffffff;
}

// La alarma pospuesta usa otro id para no pisar la diaria.
int idPospuesta(String idMedicamento) =>
    idNotificacion('pospuesta-$idMedicamento');

int idPasada(String idMedicamento) => idNotificacion('pasada-$idMedicamento');

String textoPasada(String nombre, Medicamento m) =>
    '$nombre, ya pasó la hora de tu ${m.nombre}. ¿Ya te la tomaste?';

// Cuándo NANA pregunta si ya se la tomó: la hora más la ventana de espera.
DateTime cuandoPasada(Medicamento m, DateTime ahora) => DateTime(
  ahora.year,
  ahora.month,
  ahora.day,
  m.hora.hour,
  m.hora.minute,
).add(Duration(minutes: m.ventanaMin));

// Para una medicina con último día: cada toma que falta, de la próxima hasta
// [hasta] (máximo 60). La alarma diaria de Android se repite para siempre, así
// que estas se programan una por una. Sin [hasta]: lista vacía (va la diaria).
List<DateTime> tomasHastaElFin(Medicamento m, DateTime ahora) {
  final fin = m.hasta;
  if (fin == null) return const [];
  final salida = <DateTime>[];
  var dia = DateTime(ahora.year, ahora.month, ahora.day);
  while (salida.length < 60) {
    final cuando = DateTime(
      dia.year,
      dia.month,
      dia.day,
      m.hora.hour,
      m.hora.minute,
    );
    if (!m.vigente(cuando)) break;
    if (cuando.isAfter(ahora) && m.empezo(cuando)) salida.add(cuando);
    dia = DateTime(dia.year, dia.month, dia.day + 1);
  }
  return salida;
}

// Pantallas que no se deben tapar con un recordatorio: otro recordatorio, el
// aviso de ayuda, la plática y NanaEscucha (se pelearían la voz y el micro).
// Cada una suma al abrir y resta al cerrar.
int pantallasOcupadas = 0;

// Con la app abierta: la medicina cuya hora (o cuya ventana) se cumplió en
// el último minuto, que no se ha tomado y de la que NANA todavía no avisó.
// Anota en [yaAvisado] para no repetir.
Medicamento? medicinaQueAvisar(
  List<Medicamento> meds,
  Set<String> tomadasHoy,
  DateTime ahora,
  Set<String> yaAvisado,
) {
  for (final m in meds) {
    final id = m.id;
    if (id == null || tomadasHoy.contains(id) || !m.tocaEl(ahora)) continue;
    final hora = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      m.hora.hour,
      m.hora.minute,
    );
    for (final cuando in [hora, cuandoPasada(m, ahora)]) {
      final desde = ahora.difference(cuando);
      if (desde.isNegative || desde > const Duration(minutes: 1)) continue;
      if (yaAvisado.add('$id@${cuando.hour}:${cuando.minute}')) return m;
    }
  }
  return null;
}

class AlarmasLocales implements Alarmas {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _exactaPedida = false;
  bool _exacta = true;
  AndroidScheduleMode get _modo => _exacta
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;
  bool _listo = false;
  bool _permisoPedido = false;
  String? _abiertaDesde;

  @override
  String? get abiertaDesde => _abiertaDesde;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'medicinas',
      'Medicinas',
      channelDescription: 'La hora de cada medicina',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      // Con el celular bloqueado prende la pantalla y abre el recordatorio,
      // donde NANA lo dice con su voz (como la alarma de un despertador).
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  @override
  Future<void> iniciar(void Function(String idMedicamento) alTocar) async {
    if (kIsWeb) return;
    try {
      tz.initializeTimeZones();
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) alTocar(r.payload!);
        },
      );
      final inicio = await _plugin.getNotificationAppLaunchDetails();
      if (inicio?.didNotificationLaunchApp == true) {
        _abiertaDesde = inicio!.notificationResponse?.payload;
      }
      _listo = true;
    } catch (e) {
      debugPrint('No se pudieron preparar las alarmas: $e');
    }
  }

  Future<void> _pedirPermiso() async {
    if (_permisoPedido) return;
    _permisoPedido = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    // Android 14+: abrir la pantalla completa con el celular bloqueado.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestFullScreenIntentPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  }

  tz.TZDateTime _proxima(Medicamento m) {
    final ahora = tz.TZDateTime.now(tz.local);
    var cuando = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      m.hora.hour,
      m.hora.minute,
    );
    if (!cuando.isAfter(ahora)) cuando = cuando.add(const Duration(days: 1));
    return cuando;
  }

  @override
  Future<void> programar(String nombreAdulto, List<Medicamento> meds) async {
    if (!_listo) return;
    try {
      await _pedirPermiso();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Sin permiso de alarma exacta Android la atrasa (minutos o más). En
      // Android 14 no viene dado: se pide una vez (abre «Alarmas y
      // recordatorios» para prender NANA).
      var exacta = await android?.canScheduleExactNotifications() ?? true;
      if (!exacta && !_exactaPedida) {
        _exactaPedida = true;
        await android?.requestExactAlarmsPermission();
        exacta = await android?.canScheduleExactNotifications() ?? false;
      }
      _exacta = exacta;
      // Quita las diarias de antes, pero deja las de "al rato" y las de
      // "ya se pasó" (esas las maneja programarPasadas).
      final pospuestas = {
        for (final m in meds)
          if (m.id != null) ...{idPospuesta(m.id!), idPasada(m.id!)},
      };
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (!pospuestas.contains(p.id)) await _plugin.cancel(id: p.id);
      }
      var total = 0;
      final ahora = DateTime.now();
      for (final m in meds) {
        if (m.id == null) continue;
        final dias = tomasHastaElFin(m, ahora);
        if (m.hasta == null) {
          await _plugin.zonedSchedule(
            id: idNotificacion(m.id!),
            scheduledDate: _proxima(m),
            notificationDetails: _detalles,
            androidScheduleMode: _modo,
            title: 'Hora de tu medicina',
            body: textoAlarma(nombreAdulto, m),
            payload: m.id,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          total++;
        }
        for (final cuando in dias) {
          await _plugin.zonedSchedule(
            id: idNotificacion(
              '${m.id}@${cuando.year}-${cuando.month}-${cuando.day}',
            ),
            scheduledDate: tz.TZDateTime.from(cuando, tz.local),
            notificationDetails: _detalles,
            androidScheduleMode: _modo,
            title: 'Hora de tu medicina',
            body: textoAlarma(nombreAdulto, m),
            payload: m.id,
          );
          total++;
        }
      }
      debugPrint(
        'NANA alarmas: $total programadas · exacta: ${exacta ? 'sí' : 'no'}',
      );
    } catch (e) {
      debugPrint('No se pudieron programar las alarmas: $e');
    }
  }

  @override
  Future<void> programarPasadas(
    String nombreAdulto,
    List<Medicamento> meds,
    Set<String> tomadasHoy,
  ) async {
    if (!_listo) return;
    try {
      final ahora = tz.TZDateTime.now(tz.local);
      for (final m in meds) {
        if (m.id == null) continue;
        await _plugin.cancel(id: idPasada(m.id!));
        if (tomadasHoy.contains(m.id) || !m.tocaEl(ahora)) continue;
        final cuando = cuandoPasada(m, ahora);
        if (!cuando.isAfter(ahora)) continue;
        await _plugin.zonedSchedule(
          id: idPasada(m.id!),
          scheduledDate: tz.TZDateTime.from(cuando, tz.local),
          notificationDetails: _detalles,
          androidScheduleMode: _modo,
          title: 'NANA te pregunta',
          body: textoPasada(nombreAdulto, m),
          payload: m.id,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar los avisos de "ya se pasó": $e');
    }
  }

  @override
  Future<void> posponer(String idMedicamento, String texto, Duration en) async {
    if (!_listo) return;
    try {
      await _plugin.zonedSchedule(
        id: idPospuesta(idMedicamento),
        scheduledDate: tz.TZDateTime.now(tz.local).add(en),
        notificationDetails: _detalles,
        androidScheduleMode: _modo,
        title: 'Hora de tu medicina',
        body: texto,
        payload: idMedicamento,
      );
    } catch (e) {
      debugPrint('No se pudo posponer la alarma: $e');
    }
  }
}
