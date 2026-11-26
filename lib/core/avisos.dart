import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alerta.dart';
import 'ajustes.dart';
import 'alarmas.dart';
import 'dia.dart';

// Notificaciones del celular del cuidador cuando llega una alerta nueva
// (pidió ayuda o dijo algo preocupante). Funcionan mientras NANA sigue viva,
// aunque esté minimizada o con la pantalla bloqueada. Con la app cerrada del
// todo hace falta push (FCM + Cloud Functions, plan Blaze): siguiente fase.
abstract class Avisos {
  Future<void> pedirPermiso();
  Future<void> mostrar(int id, String titulo, String cuerpo);
}

// En pruebas y en web no se muestra nada.
class AvisosNulos implements Avisos {
  const AvisosNulos();
  @override
  Future<void> pedirPermiso() async {}
  @override
  Future<void> mostrar(int id, String titulo, String cuerpo) async {}
}

// Usa el mismo plugin que las alarmas de medicina (ya lo inicia main()).
class AvisosLocales implements Avisos {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _permisoPedido = false;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'alertas_familia',
      'Alertas de tu familiar',
      channelDescription: 'Cuando pide ayuda o dice que se siente mal',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBanner: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  @override
  Future<void> pedirPermiso() async {
    if (kIsWeb || _permisoPedido) return;
    _permisoPedido = true;
    try {
      // El canal debe existir antes del primer push: con la app cerrada,
      // Android usa este canal (sonido y prioridad máxima) para el del Worker.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'alertas_familia',
              'Alertas de tu familiar',
              description: 'Cuando pide ayuda o dice que se siente mal',
              importance: Importance.max,
            ),
          );
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
    } catch (e) {
      debugPrint('No se pudo pedir permiso de avisos: $e');
    }
  }

  @override
  Future<void> mostrar(int id, String titulo, String cuerpo) async {
    if (kIsWeb) return;
    try {
      // Sin payload: al tocarla solo se abre NANA (el payload lo usan las
      // alarmas de medicina para abrir su recordatorio).
      await _plugin.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: _detalles,
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el aviso: $e');
    }
  }
}

// Título y texto de la notificación de una alerta.
(String, String) textoAviso(String nombre, Alerta a) {
  final hora = horaCorta(TimeOfDay.fromDateTime(a.fecha));
  return a.esFrase
      ? (
          '$nombre dijo: "${a.texto ?? ''}"',
          'A las $hora. Abre NANA para llamarle.',
        )
      : a.noContesto
      ? (
          '$nombre necesita ayuda y no contesta',
          'Dijo que necesitaba ayuda a las $hora y después no contestó. '
              'Llámale ya.',
        )
      : (
          '$nombre necesita ayuda',
          '${a.comoSePidio} a las $hora. Abre NANA para llamarle.',
        );
}

// Lo que NANA dice en voz alta a quien cuida.
String textoVozAlerta(String nombre, Alerta a) => a.esFrase
    ? '$nombre dijo: ${a.texto ?? ''}'
    : a.noContesto
    ? 'Atención. $nombre pidió ayuda y no contesta. Llámale ya.'
    : 'Atención. $nombre necesita ayuda. Llámale.';

// Escucha las alertas de un adulto y avisa solo de las nuevas: las que ya
// estaban cuando se abrió el panel no se vuelven a notificar.
class VigilanteAlertas {
  final Avisos avisos;
  final String nombre;
  // NANA lo dice en voz alta (con la app abierta o minimizada). Así quien
  // cuida lo oye aunque no esté viendo el celular.
  final Future<void> Function(String texto)? decir;
  // Firestore a veces manda primero lo guardado en el celular y luego lo del
  // servidor; para que una alerta vieja no parezca nueva, solo se avisa de
  // las creadas después de abrir el panel (con un minuto de margen).
  final DateTime desde;
  StreamSubscription<List<Alerta>>? _sub;
  Set<String>? _vistas;

  VigilanteAlertas({
    required this.avisos,
    required this.nombre,
    required DateTime ahora,
    this.decir,
  }) : desde = ahora.subtract(const Duration(minutes: 1));

  void escuchar(Stream<List<Alerta>> alertas) {
    _sub = alertas.listen((lista) {
      final vistas = _vistas;
      if (vistas == null) {
        _vistas = {for (final a in lista) a.id};
        return;
      }
      for (final a in lista) {
        // Las frases se pueden callar en «Mis alertas»; «pidió ayuda», nunca.
        if (a.esFrase && Ajustes.callarFrases.value) {
          vistas.add(a.id);
          continue;
        }
        if (vistas.add(a.id) && a.fecha.isAfter(desde)) {
          final (titulo, cuerpo) = textoAviso(nombre, a);
          // Con el prefijo no choca con el id de una alarma de medicina.
          avisos.mostrar(idNotificacion('alerta:${a.id}'), titulo, cuerpo);
          decir?.call(textoVozAlerta(nombre, a));
        }
      }
    });
  }

  void cancelar() => _sub?.cancel();
}
