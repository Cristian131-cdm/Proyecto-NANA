import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../widgets/mascota_nana.dart';

// Solo la interfaz: el micrófono y el agente todavía no están conectados.
class NanaEscucha extends StatefulWidget {
  const NanaEscucha({super.key});

  @override
  State<NanaEscucha> createState() => _NanaEscuchaState();
}

class _NanaEscuchaState extends State<NanaEscucha>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresNana.moradoClaro,
      appBar: AppBar(
        backgroundColor: ColoresNana.moradoClaro,
        title: const Text('Hablando con NANA'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.06).animate(
                CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
              ),
              child: const MascotaNana(tamano: 150),
            ),
            const SizedBox(height: 16),
            const Text(
              'Te escucho, ${DatosEjemplo.adulto}',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: ColoresNana.morado,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Habla con calma, sin prisa.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  Text(
                    'Así se verá la conversación:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6485)),
                  ),
                  SizedBox(height: 8),
                  _Globo(
                    texto: 'Ya me tomé la pastilla de la presión',
                    deRosa: true,
                  ),
                  _Globo(
                    texto: 'Listo, la anoté a las 8:05. Le aviso a Ana.',
                    deRosa: false,
                  ),
                  _Globo(texto: '¿Qué me toca después?', deRosa: true),
                  _Globo(
                    texto: 'La comida, a las 2 de la tarde. Yo te recuerdo.',
                    deRosa: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.stop_circle_outlined, size: 30),
                label: const Text('Terminar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Globo extends StatelessWidget {
  final String texto;
  final bool deRosa;

  const _Globo({required this.texto, required this.deRosa});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: deRosa ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: deRosa ? ColoresNana.morado : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 19,
            color: deRosa ? Colors.white : ColoresNana.tinta,
          ),
        ),
      ),
    );
  }
}
