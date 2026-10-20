import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/tema.dart';
import '../widgets/mascota_nana.dart';
import 'panel_adulto.dart';

class EncuestaApariencia extends StatelessWidget {
  const EncuestaApariencia({super.key});

  static const opciones = [
    (1.0, 'Normal'),
    (1.25, 'Grande'),
    (1.5, 'Muy grande'),
  ];

  void _continuar(BuildContext context) {
    Ajustes.encuestaHecha = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PanelAdulto()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: Ajustes.escalaTexto,
          builder: (context, actual, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                const Center(child: MascotaNana(tamano: 96)),
                const SizedBox(height: 16),
                const Text(
                  'Antes de empezar',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: ColoresNana.morado),
                ),
                const Text(
                  '¿Cuál se lee mejor?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toca el que te quede más cómodo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                ...opciones.map((o) {
                  final activa = actual == o.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: activa ? ColoresNana.moradoClaro : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: activa
                              ? ColoresNana.morado
                              : const Color(0xFFD9D2EA),
                          width: activa ? 3 : 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Ajustes.escalaTexto.value = o.$1,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          // La vista previa ignora la escala global para que
                          // las tres opciones se vean distintas entre sí.
                          child: MediaQuery.withNoTextScaling(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Buenos días, Rosa',
                                        style: TextStyle(
                                          fontSize: 22 * o.$1,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        o.$2,
                                        style: TextStyle(
                                          fontSize: 16 * o.$1,
                                          color: ColoresNana.morado,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  activa
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: activa
                                      ? ColoresNana.morado
                                      : const Color(0xFFB9B2CC),
                                  size: 34,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _continuar(context),
                  child: const Text('Así está bien'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lo puedes cambiar cuando quieras con el botón Aa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B6485)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
