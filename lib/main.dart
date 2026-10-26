import 'package:flutter/material.dart';
import 'core/ajustes.dart';
import 'core/tema.dart';
import 'screens/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Ajustes.cargar();
  runApp(const NanaApp());
}

class NanaApp extends StatelessWidget {
  const NanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: Ajustes.escalaTexto,
      builder: (context, escala, _) {
        return MaterialApp(
          title: 'NANA',
          debugShowCheckedModeBanner: false,
          theme: TemaNana.tema,
          builder: (context, child) {
            final sistema = MediaQuery.textScalerOf(context).scale(1.0);
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala * sistema)),
              child: child!,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}