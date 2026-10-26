import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/tema.dart';
import 'interruptor_huella.dart';

// (ícono, título, explicación, preferencia). Las comparten la encuesta
// inicial y la hoja de lectura y accesibilidad.
final modosDeUso = [
  (
    Icons.record_voice_over,
    'Que me hable',
    'NANA lee en voz alta y te pregunta',
    Ajustes.queMeHable,
  ),
  (
    Icons.sign_language,
    'Con señas',
    'Videos en lengua de señas',
    Ajustes.conSenas,
  ),
  (
    Icons.contrast,
    'Colores más fuertes',
    'Más contraste para ver mejor',
    Ajustes.altoContraste,
  ),
  (
    Icons.vibration,
    'Avisos con vibración y luz',
    'Por si no escuchas bien',
    Ajustes.avisoVibracion,
  ),
];

void mostrarAjustesTexto(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => const _HojaTexto(),
  );
}

class _HojaTexto extends StatelessWidget {
  const _HojaTexto();

  static const opciones = [
    (1.0, 'Normal', 22.0),
    (1.25, 'Grande', 28.0),
    (1.5, 'Muy grande', 34.0),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lectura y accesibilidad',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tamaño de letra',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<double>(
              valueListenable: Ajustes.escalaTexto,
              builder: (context, actual, _) => Row(
                children: opciones.map((o) {
                  final activa = actual == o.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        button: true,
                        selected: activa,
                        label: 'Letra ${o.$2}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Ajustes.escalaTexto.value = o.$1,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: activa
                                  ? ColoresNana.moradoClaro
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: activa
                                    ? ColoresNana.morado
                                    : const Color(0xFFD9D2EA),
                                width: activa ? 3 : 1,
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Column(
                                children: [
                                  Text(
                                    'Aa',
                                    style: TextStyle(
                                      fontSize: o.$3,
                                      fontWeight: FontWeight.bold,
                                      color: ColoresNana.morado,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    o.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: activa
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cómo prefieres usar NANA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final m in modosDeUso)
              ValueListenableBuilder<bool>(
                valueListenable: m.$4,
                builder: (context, encendido, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(m.$1, color: ColoresNana.morado, size: 30),
                  title: Text(
                    m.$2,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(m.$3, style: const TextStyle(fontSize: 15)),
                  value: encendido,
                  onChanged: (v) => m.$4.value = v,
                ),
              ),
            const InterruptorHuella(),
            const SizedBox(height: 8),
            const Text(
              'Pronto: la voz, las señas, los colores y la vibración todavía '
              'no cambian nada. Ya quedan guardados para cuando estén listos.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B6485)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande que se marca o desmarca. Lleva ícono, texto y palomita para
/// que no dependa solo del color.
class TarjetaModo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool marcada;
  final VoidCallback onTap;

  const TarjetaModo({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.marcada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: marcada,
        child: Material(
          color: marcada ? ColoresNana.moradoClaro : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: marcada ? ColoresNana.morado : const Color(0xFFD9D2EA),
              width: marcada ? 3 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icono, size: 36, color: ColoresNana.morado),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(detalle, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  Icon(
                    marcada ? Icons.check_box : Icons.check_box_outline_blank,
                    color: marcada
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
  }
}
