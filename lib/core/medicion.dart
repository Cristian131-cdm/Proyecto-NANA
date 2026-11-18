import 'package:flutter/material.dart';

// Estudio de uso: para saber en qué pantallas se atora la gente.
//
// Qué se anota: qué pantalla se abrió, cuántos segundos estuvo ahí, si se
// regresó, si salió un mensaje de error y qué tareas se completaron.
// Qué NO se anota: nombres, textos que la persona escribe, medicinas, datos
// de salud ni quién es. Cada celular se identifica con un número al azar.
// Solo funciona si el encargado principal lo prendió (Adulto.estudio).

enum TipoEvento { pantalla, regreso, error, tarea }

class EventoUso {
  final TipoEvento tipo;
  final String pantalla; // nombre de la pantalla, o de la tarea
  final int segundos; // solo en "pantalla": cuánto estuvo ahí
  final DateTime fecha;

  const EventoUso({
    required this.tipo,
    required this.pantalla,
    this.segundos = 0,
    required this.fecha,
  });

  Map<String, dynamic> aMapa() => {
    't': tipo.name,
    'p': pantalla,
    if (segundos > 0) 's': segundos,
    'f': fecha.millisecondsSinceEpoch,
  };

  static EventoUso? deMapa(Map<String, dynamic> m) {
    final tipo = TipoEvento.values.where((t) => t.name == m['t']).firstOrNull;
    if (tipo == null || m['p'] is! String || m['f'] is! int) return null;
    return EventoUso(
      tipo: tipo,
      pantalla: m['p'] as String,
      segundos: (m['s'] as num?)?.toInt() ?? 0,
      fecha: DateTime.fromMillisecondsSinceEpoch(m['f'] as int),
    );
  }
}

// Las pantallas que se reconocen por su clase. Lo demás cuenta como "otra":
// así nunca se cuela un nombre que no esté en esta lista.
const pantallasConocidas = {
  'Bienvenida': 'Bienvenida',
  'OpcionesCuidador': 'Soy cuidador o familiar',
  'CuentaCuidador': 'Cuenta del cuidador',
  'InvitadoConCodigo': 'Código de invitación',
  'UnirmeConCodigo': 'Unirme con código',
  'EntrarConCodigo': 'Entrar con un código',
  'AltaAdulto': 'Alta de la persona',
  'FormularioSalud': 'Datos de salud',
  'PantallaCodigo': 'Código para el adulto',
  'SinCelular': 'Sin celular',
  'RecomendarHuella': 'Recomendar huella',
  'Candado': 'Candado',
  'EncuestaApariencia': 'Encuesta de apariencia',
  'PanelAdulto': 'Inicio del adulto',
  'MiDia': 'Mi día',
  'MiFamilia': 'Mi familia',
  'NanaEscucha': 'Hablar con NANA',
  'PlaticaNana': 'Platicando con NANA',
  'TableroFrases': 'Decir (tablero)',
  'RecordatorioAlarma': 'Recordatorio',
  'VerEnSenas': 'Ver en señas',
  'ConsentimientoCamara': 'Permiso de cámara',
  'CamaraSenas': 'Cámara de señas',
  'PanelCuidador': 'Panel del cuidador',
  'FamiliaAlertas': 'Familia y alertas',
  'PantallaPrivacidad': 'Tus datos',
  'PantallaDelAdulto': 'Pantalla del adulto',
  'MisAjustes': 'Mis ajustes',
  'PestanaRutinas': 'Rutinas',
  'PestanaHistorial': 'Su expediente',
  'ExpedientePrivado': 'Su expediente',
  'ComoVaLaPrueba': 'Cómo va la prueba',
};

class Medicion {
  // Lo prende el panel cuando el encargado aceptó el estudio.
  static bool activa = false;
  static DateTime Function() reloj = DateTime.now;
  // Quién manda los eventos: lo pone main() (a Firestore). En pruebas, a una lista.
  static Future<void> Function(List<EventoUso> lote)? enviar;

  static final observador = ObservadorUso();
  static final _pendientes = <EventoUso>[];
  static const _lote = 15;

  static List<EventoUso> get pendientes => List.unmodifiable(_pendientes);

  static void _anotar(TipoEvento tipo, String pantalla, {int segundos = 0}) {
    if (!activa) return;
    _pendientes.add(
      EventoUso(
        tipo: tipo,
        pantalla: pantalla,
        segundos: segundos,
        fecha: reloj(),
      ),
    );
    if (_pendientes.length >= _lote) mandar();
  }

  // Una tarea que la persona sí terminó (ej. 'alta', 'pidio_ayuda').
  static void tarea(String nombre) => _anotar(TipoEvento.tarea, nombre);

  // Salió un mensaje de error en la pantalla actual. El texto no se guarda.
  static void error() => _anotar(TipoEvento.error, observador.actual);

  // Manda lo acumulado. Si falla (sin internet) se queda para el siguiente.
  static Future<void> mandar() async {
    final envia = enviar;
    if (envia == null || _pendientes.isEmpty) return;
    final lote = List.of(_pendientes);
    _pendientes.clear();
    try {
      await envia(lote);
    } catch (_) {
      // A lo más se guardan 200 para no crecer sin fin.
      _pendientes.insertAll(0, lote);
      if (_pendientes.length > 200) {
        _pendientes.removeRange(0, _pendientes.length - 200);
      }
    }
  }

  static void reiniciar() {
    _pendientes.clear();
    activa = false;
    enviar = null;
    reloj = DateTime.now;
    observador._actual = null;
  }
}

// Mira qué pantalla está abierta y cuánto dura. Va en MaterialApp.
class ObservadorUso extends NavigatorObserver {
  final _nombres = Expando<String>();
  Route<dynamic>? _actual;
  DateTime? _desde;

  String get actual => _actual == null ? 'otra' : _nombres[_actual!] ?? 'otra';

  String _nombreDe(Route<dynamic> ruta) {
    if (ruta is PopupRoute) return ruta is DialogRoute ? 'Diálogo' : 'Hoja';
    String? hallado;
    void baja(Element e, int nivel) {
      if (hallado != null || nivel > 14) return;
      final conocida = pantallasConocidas[e.widget.runtimeType.toString()];
      if (conocida != null) {
        hallado = conocida;
        return;
      }
      e.visitChildren((hijo) => baja(hijo, nivel + 1));
    }

    if (ruta is ModalRoute) {
      ruta.subtreeContext?.visitChildElements((e) => baja(e, 0));
    }
    return hallado ?? 'otra';
  }

  void _cerrarActual() {
    final ruta = _actual;
    final desde = _desde;
    if (ruta == null || desde == null) return;
    final segundos = Medicion.reloj().difference(desde).inSeconds;
    // Menos de un segundo es solo pasar por ahí.
    if (segundos >= 1) {
      Medicion._anotar(
        TipoEvento.pantalla,
        _nombres[ruta] ?? 'otra',
        segundos: segundos,
      );
    }
  }

  void _abrir(Route<dynamic>? ruta) {
    _actual = ruta;
    _desde = Medicion.reloj();
    if (ruta == null || _nombres[ruta] != null) return;
    // La pantalla todavía no se dibuja: su nombre se averigua al terminar el cuadro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nombres[ruta] ??= _nombreDe(ruta);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _cerrarActual();
    _abrir(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _cerrarActual();
    Medicion._anotar(TipoEvento.regreso, _nombres[route] ?? 'otra');
    _abrir(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _cerrarActual();
    _abrir(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == _actual) {
      _cerrarActual();
      _abrir(previousRoute);
    }
  }
}

// Lo que se ve en "Cómo va la prueba": una fila por pantalla.
class UsoDePantalla {
  final String pantalla;
  int visitas = 0;
  int segundos = 0;
  int regresos = 0;
  int errores = 0;
  UsoDePantalla(this.pantalla);

  int get promedio => visitas == 0 ? 0 : (segundos / visitas).round();
  // Entre más regresos y errores por visita, más se atora la gente ahí.
  double get tropiezos =>
      (regresos + errores * 2) / (visitas == 0 ? 1 : visitas);
}

class ResumenUso {
  final List<UsoDePantalla> pantallas; // primero donde más se atoran
  final Map<String, int> tareas;
  final int eventos;
  const ResumenUso(this.pantallas, this.tareas, this.eventos);
}

ResumenUso resumirUso(List<EventoUso> eventos) {
  final porPantalla = <String, UsoDePantalla>{};
  final tareas = <String, int>{};
  for (final e in eventos) {
    if (e.tipo == TipoEvento.tarea) {
      tareas[e.pantalla] = (tareas[e.pantalla] ?? 0) + 1;
      continue;
    }
    // Hojas, diálogos y lo no reconocido no dicen nada de una pantalla.
    if (const {'otra', 'Hoja', 'Diálogo'}.contains(e.pantalla)) continue;
    final u = porPantalla.putIfAbsent(
      e.pantalla,
      () => UsoDePantalla(e.pantalla),
    );
    switch (e.tipo) {
      case TipoEvento.pantalla:
        u.visitas++;
        u.segundos += e.segundos;
      case TipoEvento.regreso:
        u.regresos++;
      case TipoEvento.error:
        u.errores++;
      case TipoEvento.tarea:
        break;
    }
  }
  final lista = porPantalla.values.toList()
    ..sort((a, b) {
      final t = b.tropiezos.compareTo(a.tropiezos);
      return t != 0 ? t : b.visitas.compareTo(a.visitas);
    });
  return ResumenUso(lista, tareas, eventos.length);
}

const nombresDeTareas = {
  'cuenta_creada': 'Crear cuenta',
  'invitacion_usada': 'Unirse con invitación',
  'alta': 'Dar de alta a la persona',
  'invitacion_creada': 'Invitar a un familiar',
  'receta_guardada': 'Guardar una receta',
  'pantalla_ajustada': 'Ajustar la pantalla del adulto',
  'registro': 'Anotar algo del día (adulto)',
  'pidio_ayuda': 'Pedir ayuda (adulto)',
};
