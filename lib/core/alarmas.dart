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

class AlarmasLocales implements Alarmas {
  final _plugin = FlutterLocalNotificationsPlugin();
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
      // Si no dan permiso de alarma exacta, suena unos minutos tarde.
      final exacta = await android?.canScheduleExactNotifications() ?? true;
      await _plugin.cancelAllPendingNotifications();
      for (final m in meds) {
        if (m.id == null) continue;
        await _plugin.zonedSchedule(
          id: idNotificacion(m.id!),
          scheduledDate: _proxima(m),
          notificationDetails: _detalles,
          androidScheduleMode: exacta
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Hora de tu medicina',
          body: textoAlarma(nombreAdulto, m),
          payload: m.id,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar las alarmas: $e');
    }
  }
}
