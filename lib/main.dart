import 'package:flutter/material.dart';
import 'core/tema.dart';
import 'screens/splash.dart';

void main() {
  runApp(const NanaApp());
}

class NanaApp extends StatelessWidget {
  const NanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NANA',
      debugShowCheckedModeBanner: false,
      theme: TemaNana.tema,
      home: const SplashScreen(),
    );
  }
}