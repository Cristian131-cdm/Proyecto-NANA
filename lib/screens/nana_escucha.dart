import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/hoja_frases.dart';
import '../widgets/mascota_nana.dart';
import 'senas.dart';

// Hablar con NANA. El micrófono y el agente todavía no están conectados;
// mientras, se le dice algo con las frases rápidas o con señas.
class NanaEscucha extends StatefulWidget {
  final String nombre;
  final ValueChanged<String> onFrase;

  const NanaEscucha({super.key, required this.nombre, required this.onFrase});

  static const frases = [
    'Ya tomé mi medicina',
    'Ya comí',
    'Me siento mal',
    '¿Qué sigue hoy?',
  ];

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

  void _decir(String frase) {
    Navigator.pop(context);
    widget.onFrase(frase);
  }

  Future<void> _masFrases() async {
    final f = await mostrarHojaFrases(context);
    if (f != null && mounted) _decir(f);
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
                ),
                child: const MascotaNana(tamano: 130),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Te escucho, ${widget.nombre}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: ColoresNana.morado,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Habla con calma, o toca lo que me quieres decir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final f in NanaEscucha.frases)
                  BotonFrase(frase: f, onTap: () => _decir(f)),
                ActionChip(
                  avatar: const Icon(Icons.add, color: ColoresNana.morado),
                  label: const Text(
                    'Más frases',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ColoresNana.morado,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: ColoresNana.lila, width: 2),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  onPressed: _masFrases,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Forma(
                    icono: Icons.ondemand_video,
                    titulo: 'Ver en señas',
                    onTap: () => abrirVerEnSenas(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Forma(
                    icono: Icons.videocam_outlined,
                    titulo: 'Hablar con señas',
                    onTap: () => abrirHablarConSenas(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.stop_circle_outlined, size: 30),
              label: const Text('Terminar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Forma extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  const _Forma({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: ColoresNana.lila, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: ColoresNana.morado, size: 36),
              const SizedBox(height: 8),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
