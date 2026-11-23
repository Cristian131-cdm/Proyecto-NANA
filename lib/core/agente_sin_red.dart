import 'agente.dart';

// En web no hay dart:io: la plática contesta como siempre, sin agente.
Agente crearAgente() => const AgenteNulo();
