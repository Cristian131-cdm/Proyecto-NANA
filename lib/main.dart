import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/ocr_sin_camara.dart' if (dart.library.io) 'core/ocr_celular.dart';
import 'core/push_sin_red.dart' if (dart.library.io) 'core/push_celular.dart';
import 'core/agente_sin_red.dart' if (dart.library.io) 'core/agente_red.dart';
import 'core/ajustes.dart';
import 'core/avisos.dart';
import 'core/despertador.dart';
import 'core/despertador_sin_vosk.dart'
    if (dart.library.io) 'core/despertador_vosk.dart';
import 'core/medicion.dart';
import 'core/fotos_sin_disco.dart' if (dart.library.io) 'core/fotos_disco.dart';
import 'core/senas/ojo_sin_camara.dart'
    if (dart.library.io) 'core/senas/ojo_camara.dart';
import 'core/servicios.dart';
import 'core/tema.dart';
import 'core/voz.dart';
import 'data/repositorio_firebase.dart';
import 'firebase_options.dart';
import 'screens/candado.dart';
import 'screens/recordatorio_alarma.dart';
import 'screens/splash.dart';
import 'widgets/marco_ancho.dart';

// Se guarda para que siga vivo mientras la app está abierta.
// ignore: unused_element
AppLifecycleListener? _alMinimizar;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Servicios.repo = RepositorioFirebase();
  Servicios.avisos = AvisosLocales();
  Servicios.voz = VozCelular();
  Servicios.despertador = crearDespertador();
  Servicios.fotos = crearFotos();
  Servicios.agente = crearAgente();
  Servicios.push = crearPush();
  Servicios.ocr = crearOcr();
  Servicios.crearOjo = crearOjoCamara;
  await Ajustes.cargar();
  // Al minimizar la app se manda lo que el estudio de uso tenga pendiente.
  _alMinimizar = AppLifecycleListener(onPause: Medicion.mandar);
  VigilanteCandado.instancia.iniciar();
  await Servicios.alarmas.iniciar(abrirDesdeAlarma);
  VigilanteCandado.instancia.vieneDeAlarma =
      Servicios.alarmas.abiertaDesde != null;
  runApp(const NanaApp());
}

class NanaApp extends StatelessWidget {
  const NanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Ajustes.escalaTexto,
        Ajustes.altoContraste,
        Ajustes.menosMovimiento,
      ]),
      builder: (context, _) {
        final fuerte = Ajustes.altoContraste.value;
        return MaterialApp(
          title: 'NANA',
          navigatorKey: VigilanteCandado.instancia.navegador,
          navigatorObservers: [Medicion.observador, rutasNana],
          debugShowCheckedModeBanner: false,
          theme: TemaNana.tema,
          // Fechas, horas ("10:00 a. m."), calendario y botones del sistema
          // en español de México.
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            final sistema = MediaQuery.textScalerOf(context).scale(1.0);
            final contenido = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(Ajustes.escalaTotal(sistema)),
                // Con colores fuertes también la letra va en negritas.
                boldText: fuerte || MediaQuery.boldTextOf(context),
                // "Menos movimiento" apaga las animaciones de toda la app.
                disableAnimations:
                    Ajustes.menosMovimiento.value ||
                    MediaQuery.disableAnimationsOf(context),
              ),
              child: MarcoAncho(child: child!),
            );
            // Siempre el mismo árbol: si el filtro apareciera y desapareciera,
            // Flutter recrearía el navegador y se perdería la pantalla abierta.
            return ColorFiltered(
              colorFilter: fuerte
                  ? TemaNana.filtroAltoContraste
                  : TemaNana.filtroNeutro,
              child: contenido,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
