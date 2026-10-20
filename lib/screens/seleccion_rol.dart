import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/tema.dart';
import '../widgets/mascota_nana.dart';
import 'encuesta_apariencia.dart';
import 'panel_adulto.dart';
import 'panel_cuidador.dart';

class SeleccionRol extends StatelessWidget {
  const SeleccionRol({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotaNana(tamano: 140),
              const SizedBox(height: 20),
              const Text(
                'NANA',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: ColoresNana.morado,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nunca Ausente, Nunca Abandonad@',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Ajustes.encuestaHecha
                        ? const PanelAdulto()
                        : const EncuestaApariencia(),
                  ),
                ),
                child: const Text('Soy adulto mayor'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PanelCuidador()),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                  foregroundColor: ColoresNana.morado,
                  side: const BorderSide(color: ColoresNana.lila, width: 2),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Soy cuidador o familiar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
