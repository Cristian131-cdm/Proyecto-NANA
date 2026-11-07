import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/ajustes.dart';
import 'core/servicios.dart';
import 'core/tema.dart';
import 'data/repositorio_firebase.dart';
import 'firebase_options.dart';
import 'screens/candado.dart';
import 'screens/recordatorio_alarma.dart';
import 'screens/splash.dart';
import 'widgets/marco_ancho.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Servicios.repo = RepositorioFirebase();
  await Ajustes.cargar();
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
      ]),
      builder: (context, _) {
        final escala = Ajustes.escalaTexto.value;
        final fuerte = Ajustes.altoContraste.value;
        return MaterialApp(
          title: 'NANA',
          navigatorKey: VigilanteCandado.instancia.navegador,
          debugShowCheckedModeBanner: false,
          theme: TemaNana.tema,
          builder: (context, child) {
            final sistema = MediaQuery.textScalerOf(context).scale(1.0);
            final contenido = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(escala * sistema),
                // Con colores fuertes también la letra va en negritas.
                boldText: fuerte || MediaQuery.boldTextOf(context),
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
