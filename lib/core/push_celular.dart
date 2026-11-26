import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'alarmas.dart';
import 'push.dart';
import 'servicios.dart';

Push crearPush() => PushCelular();

class PushCelular implements Push {
  bool _listo = false;

  @override
  Future<void> registrar() async {
    if (_listo) return;
    _listo = true;
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      // getToken/onTokenRefresh están marcados como viejos en
      // firebase_messaging 17 (ahora register() da un FID), pero el Worker
      // manda por FCM HTTP v1 con `message.token`, que es este token.
      // ignore: deprecated_member_use
      final token = await fcm.getToken();
      if (token != null) await Servicios.repo.guardarTokenPush(token);
      // ignore: deprecated_member_use
      fcm.onTokenRefresh.listen(
        (t) => Servicios.repo.guardarTokenPush(t).ignore(),
      );
      FirebaseMessaging.onMessage.listen((m) {
        final p = pushEnPantalla(
          m.data,
          m.notification?.title,
          m.notification?.body,
        );
        if (p == null) return;
        Servicios.avisos.mostrar(
          idNotificacion('push:${m.messageId}'),
          p.titulo,
          p.cuerpo,
        );
        Servicios.voz.decir(p.titulo);
      });
    } catch (e) {
      _listo = false;
      registrarFalla('registrar este celular', e);
    }
  }

  @override
  Future<void> avisarAhora(String folio) async {
    if (urlAvisos.isEmpty) return;
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final pedido = await cliente.postUrl(Uri.parse('$urlAvisos/ahora'));
      final bytes = utf8.encode(jsonEncode({'folio': folio}));
      pedido.headers.contentType = ContentType.json;
      // Sin contentLength Dart manda «chunked» (ver gotcha del agente).
      pedido.contentLength = bytes.length;
      pedido.add(bytes);
      await (await pedido.close()).drain<void>();
    } catch (e) {
      registrarFalla('avisar al Worker', e); // el cron lo manda en ≤ 1 min
    } finally {
      cliente.close();
    }
  }
}
