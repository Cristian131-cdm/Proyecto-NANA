import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ajustes de este celular. Se guardan en el aparato y no en Firestore,
// porque dependen de quién lo tiene en la mano y de su pantalla.
class Ajustes {
  static final ValueNotifier<double> escalaTexto = ValueNotifier(1.0);

  // La letra de NANA se multiplica por la del celular. Sin tope, letra
  // "enorme" en los dos lados daba 3x y las pantallas dejaban de caber.
  static const escalaMaxima = 2.0;
  static double escalaTotal(double sistema) =>
      (escalaTexto.value * sistema).clamp(0.85, escalaMaxima);
  // Qué tan rápido habla NANA: 0.6 despacio, 1 normal, 1.4 rápido.
  static final ValueNotifier<double> velocidadVoz = ValueNotifier(1.0);

  // La encuesta de apariencia solo se muestra la primera vez
  static final ValueNotifier<bool> encuestaHecha = ValueNotifier(false);

  // Cómo prefiere usar NANA. altoContraste cambia toda la app (main.dart) y
  // queMeHable hace que NANA lea cada pantalla (core/lector.dart); las señas
  // y la vibración por ahora solo se guardan.
  static final ValueNotifier<bool> queMeHable = ValueNotifier(false);
  static final ValueNotifier<bool> conSenas = ValueNotifier(false);
  static final ValueNotifier<bool> altoContraste = ValueNotifier(false);
  static final ValueNotifier<bool> avisoVibracion = ValueNotifier(false);
  // Sin animaciones (además de lo que diga el sistema del celular).
  static final ValueNotifier<bool> menosMovimiento = ValueNotifier(false);

  // «Oye NANA»: con NANA abierta, decir la frase abre la plática. Apagado
  // por defecto: el micrófono solo se usa si la persona (o el encargado) lo
  // prende.
  static final ValueNotifier<bool> oyeNana = ValueNotifier(false);

  // Para quien no habla: contesta tocando, nada espera su voz.
  static final ValueNotifier<bool> sinVoz = ValueNotifier(false);
  // Para quien no ve: en el recordatorio, tocar cualquier parte es "sí".
  static final ValueNotifier<bool> pantallaEsBoton = ValueNotifier(false);
  // Las discapacidades (de sus datos de salud) que ya se aplicaron aquí, para
  // no volver a prender lo que la persona apagó. Ver perfil_accesibilidad.dart.
  static final ValueNotifier<String> discapacidadesAplicadas = ValueNotifier(
    '',
  );

  // La última apariencia que mandó el encargado y ya se aplicó aquí, para no
  // pisar lo que la persona cambie después en "Aa".
  static final ValueNotifier<String> aparienciaAplicada = ValueNotifier('');

  // Huella o Face ID: si está activada y si ya se le ofreció una vez.
  static final ValueNotifier<bool> huellaActivada = ValueNotifier(false);
  static final ValueNotifier<bool> huellaOfrecida = ValueNotifier(false);

  static Map<String, ValueNotifier<bool>> get _interruptores => {
    'encuesta_hecha': encuestaHecha,
    'que_me_hable': queMeHable,
    'con_senas': conSenas,
    'alto_contraste': altoContraste,
    'aviso_vibracion': avisoVibracion,
    'menos_movimiento': menosMovimiento,
    'sin_voz': sinVoz,
    'oye_nana': oyeNana,
    'pantalla_es_boton': pantallaEsBoton,
    'huella_activada': huellaActivada,
    'huella_ofrecida': huellaOfrecida,
  };

  static SharedPreferences? _prefs;

  // Lee lo guardado y, la primera vez, empieza a guardar cada cambio.
  static Future<void> cargar() async {
    final primeraVez = _prefs == null;
    final prefs = _prefs = await SharedPreferences.getInstance();
    // En pruebas cada setMockInitialValues crea otra instancia
    await prefs.reload();

    escalaTexto.value = prefs.getDouble('escala_texto') ?? 1.0;
    velocidadVoz.value = prefs.getDouble('velocidad_voz') ?? 1.0;
    discapacidadesAplicadas.value =
        prefs.getString('discapacidades_aplicadas') ?? '';
    aparienciaAplicada.value = prefs.getString('apariencia_aplicada') ?? '';
    for (final MapEntry(key: clave, value: n) in _interruptores.entries) {
      n.value = prefs.getBool(clave) ?? false;
    }

    if (!primeraVez) return;
    escalaTexto.addListener(
      () => _prefs?.setDouble('escala_texto', escalaTexto.value),
    );
    velocidadVoz.addListener(
      () => _prefs?.setDouble('velocidad_voz', velocidadVoz.value),
    );
    discapacidadesAplicadas.addListener(
      () => _prefs?.setString(
        'discapacidades_aplicadas',
        discapacidadesAplicadas.value,
      ),
    );
    aparienciaAplicada.addListener(
      () => _prefs?.setString('apariencia_aplicada', aparienciaAplicada.value),
    );
    for (final MapEntry(key: clave, value: n) in _interruptores.entries) {
      n.addListener(() => _prefs?.setBool(clave, n.value));
    }
  }
}
