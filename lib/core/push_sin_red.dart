import 'push.dart';

// En web no hay push de NANA (no hay dart:io ni FCM configurado).
Push crearPush() => PushNulo();
