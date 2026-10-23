import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/aviso.dart';

/// LSM mínima del Charter: NANA muestra frases en señas con un avatar o
/// video pregrabado. Los videos todavía no existen.
class VerEnSenas extends StatelessWidget {
  const VerEnSenas({super.key});

  static const frases = [
    'Hola, soy NANA',
    'Te toca tu medicina',
    '¿Cómo te sientes?',
    '¿Ya comiste?',
    'Le aviso a tu familia',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ver en señas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: ColoresNana.moradoClaro,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sign_language,
                    size: 80,
                    color: ColoresNana.morado,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Aquí va el video en señas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Todavía no hay videos grabados',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Toca una frase para verla',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          for (final f in frases)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(
                    color: ColoresNana.moradoClaro,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  minVerticalPadding: 16,
                  leading: const Icon(
                    Icons.play_circle_outline,
                    color: ColoresNana.morado,
                    size: 34,
                  ),
                  title: Text(f, style: const TextStyle(fontSize: 20)),
                  onTap: () => mostrarAviso(context, 'Video pendiente: $f'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Se muestra cada vez, antes de prender la cámara. Sin este "sí" la cámara
/// nunca se usa.
class ConsentimientoCamara extends StatelessWidget {
  const ConsentimientoCamara({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hablar con señas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 56,
                backgroundColor: ColoresNana.moradoClaro,
                child: Icon(
                  Icons.videocam_outlined,
                  size: 60,
                  color: ColoresNana.morado,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Puedo usar tu cámara?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const _Promesa(
              icono: Icons.sign_language,
              texto: 'Solo la uso para ver tus señas.',
            ),
            const _Promesa(
              icono: Icons.no_photography_outlined,
              texto: 'No grabo ni guardo nada.',
            ),
            const _Promesa(
              icono: Icons.power_settings_new,
              texto: 'Se apaga cuando sales de esta pantalla.',
            ),
            const _Promesa(
              icono: Icons.phone_android,
              texto:
                  'Todo pasa en tu celular. Tu familia solo ve lo que dijiste.',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CamaraSenas()),
              ),
              icon: const Icon(Icons.videocam, size: 30),
              label: const Text('Sí, usar la cámara'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresNana.morado,
                  side: const BorderSide(color: ColoresNana.lila, width: 2),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('No, gracias'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Promesa extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Promesa({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icono, color: ColoresNana.morado, size: 32),
          const SizedBox(width: 14),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 20))),
        ],
      ),
    );
  }
}

/// Maqueta de la cámara. No abre la cámara real: el reconocimiento de señas
/// quedó como trabajo futuro (opción 2 acordada con el equipo).
class CamaraSenas extends StatelessWidget {
  const CamaraSenas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1426),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cámara encendida',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2240),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: ColoresNana.lila, width: 2),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.back_hand_outlined,
                        size: 96,
                        color: Colors.white70,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Haz tu seña frente a la cámara',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'De prueba: todavía no reconoce señas',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.videocam_off, size: 32),
                  label: const Text('Apagar cámara'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB3261E),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atajo para que cualquier pantalla abra el flujo con permiso previo.
void abrirHablarConSenas(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ConsentimientoCamara()),
  );
}

void abrirVerEnSenas(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const VerEnSenas()),
  );
}
