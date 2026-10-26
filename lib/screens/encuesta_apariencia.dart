import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/tema.dart';
import '../widgets/ajustes_texto.dart';
import '../widgets/mascota_nana.dart';
import 'panel_adulto.dart';

// Dos pasos: primero el tamaño de letra y luego cómo prefiere usar NANA.
class EncuestaApariencia extends StatefulWidget {
  const EncuestaApariencia({super.key});

  static const opciones = [
    (1.0, 'Normal'),
    (1.25, 'Grande'),
    (1.5, 'Muy grande'),
  ];

  @override
  State<EncuestaApariencia> createState() => _EncuestaAparienciaState();
}

class _EncuestaAparienciaState extends State<EncuestaApariencia> {
  int _paso = 1;

  void _terminar() {
    Ajustes.encuestaHecha.value = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PanelAdulto()),
    );
  }

  Widget _encabezado(String arriba, String titulo, String abajo) => Column(
    children: [
      const Center(child: MascotaNana(tamano: 96)),
      const SizedBox(height: 16),
      Text(
        arriba,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: ColoresNana.morado),
      ),
      Text(
        titulo,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        abajo,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _pasoLetra(double actual) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _encabezado(
          'Antes de empezar · 1 de 2',
          '¿Cuál se lee mejor?',
          'Toca el que te quede más cómodo.',
        ),
        ...EncuestaApariencia.opciones.map((o) {
          final activa = actual == o.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: activa ? ColoresNana.moradoClaro : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: activa ? ColoresNana.morado : const Color(0xFFD9D2EA),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                          activa ? Icons.check_circle : Icons.circle_outlined,
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
          onPressed: () => setState(() => _paso = 2),
          child: const Text('Así está bien'),
        ),
      ],
    );
  }

  Widget _pasoModos() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _encabezado(
          'Antes de empezar · 2 de 2',
          '¿Cómo prefieres usar NANA?',
          'Marca las que quieras. Puedes no marcar ninguna.',
        ),
        for (final m in modosDeUso)
          ValueListenableBuilder<bool>(
            valueListenable: m.$4,
            builder: (context, marcada, _) => TarjetaModo(
              icono: m.$1,
              titulo: m.$2,
              detalle: m.$3,
              marcada: marcada,
              onTap: () => m.$4.value = !marcada,
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _terminar, child: const Text('Listo')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _paso = 1),
          child: const Text('Regresar', style: TextStyle(fontSize: 18)),
        ),
        const Text(
          'Lo puedes cambiar cuando quieras con el botón Aa.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Color(0xFF6B6485)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: Ajustes.escalaTexto,
          builder: (context, actual, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_paso),
              child: _paso == 1 ? _pasoLetra(actual) : _pasoModos(),
            ),
          ),
        ),
      ),
    );
  }
}
