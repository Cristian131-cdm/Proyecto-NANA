import 'package:flutter/material.dart';
import '../core/tema.dart';
import '../widgets/ajustes_texto.dart';
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
  ];

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días,';
    if (h < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  String _fecha() {
    const dias = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final n = DateTime.now();
    final texto = '${dias[n.weekday - 1]} ${n.day} de ${meses[n.month - 1]}';
    return '${texto[0].toUpperCase()}${texto.substring(1)}';
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 20))),
    );
  }

  Future<void> _confirmarAviso() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Avisar a tu familia?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Le mandaré un aviso para que sepan que necesitas ayuda.',
                style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.alerta,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: const Text('Sí, avisar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('No, cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
    if (si == true) _aviso('Aquí se enviará el aviso a la familia');
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(texto,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields, size: 30),
            tooltip: 'Tamaño de letra',
            onPressed: () => mostrarAjustesTexto(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ColoresNana.moradoClaro,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
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
                      Text(_fecha(), style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
              return ActionChip(
                label: Text(f,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ColoresNana.morado)),
                backgroundColor: ColoresNana.moradoClaro,
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: ColoresNana.moradoClaro, width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _BotonGrande(
                  icono: Icons.mic,
                  texto: 'Hablar con NANA',
                  fondo: ColoresNana.azul,
                  frente: Colors.white,
                  onTap: () => _aviso('Aquí se activará el micrófono'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _BotonGrande(
                  icono: Icons.notifications_active,
                  texto: 'Avisar a mi familia',
                  fondo: ColoresNana.alertaClaro,
                  frente: ColoresNana.alerta,
                  borde: ColoresNana.alerta,
                  onTap: _confirmarAviso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color fondo;
  final Color frente;
  final Color? borde;
  final VoidCallback onTap;

  const _BotonGrande({
    required this.icono,
    required this.texto,
    required this.fondo,
    required this.frente,
    required this.onTap,
    this.borde,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: borde != null
            ? BorderSide(color: borde!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 34, color: frente),
              const SizedBox(height: 4),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: frente),
              ),
            ],
          ),
        ),
      ),
    );
  }
}