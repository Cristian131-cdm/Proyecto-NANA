import 'package:flutter/material.dart';
import '../core/tema.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/mascota_nana.dart';
import '../widgets/tarjeta_medicamento.dart';

class PanelAdulto extends StatefulWidget {
  const PanelAdulto({super.key});

  @override
  State<PanelAdulto> createState() => _PanelAdultoState();
}

class _PanelAdultoState extends State<PanelAdulto> {
  bool medicamentoTomado = false;
  int? animo;

  final frases = const [
    'Ya tomé mi medicina',
    'Me siento bien',
    'Me siento mal',
    'Ya comí',
    '¿Qué sigue hoy?',
    'Necesito ayuda',
  ];

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días,';
    if (h < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 20))),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(texto,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi día')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Row(
              children: [
                const MascotaNana(tamano: 76),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_saludo(), style: const TextStyle(fontSize: 22)),
                      const Text('Rosa',
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: ColoresNana.morado)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TarjetaMedicamento(
              nombre: 'Losartán',
              dosis: '50 mg',
              hora: '8:00 am',
              tomada: medicamentoTomado,
              onTomar: () {
                setState(() => medicamentoTomado = true);
                _aviso('¡Muy bien! Registré tu medicina');
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 76,
              child: FilledButton.icon(
                onPressed: () => _aviso('Aquí se activará el micrófono'),
                icon: const Icon(Icons.mic, size: 34),
                label: const Text('Hablar con NANA'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.azul,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            _titulo('¿Cómo te sientes hoy?'),
            CaritasAnimo(
              seleccionado: animo,
              onSeleccion: (i) {
                setState(() => animo = i);
                _aviso('Gracias por contarme');
              },
            ),
            _titulo('Frases rápidas'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: frases.map((f) {
                final ayuda = f == 'Necesito ayuda';
                return ActionChip(
                  label: Text(f,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: ayuda
                              ? ColoresNana.alerta
                              : ColoresNana.morado)),
                  backgroundColor:
                      ayuda ? ColoresNana.alertaClaro : ColoresNana.moradoClaro,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  onPressed: () => _aviso('NANA recibió: $f'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}