import 'package:flutter/material.dart';
import '../core/tema.dart';

class CaritasAnimo extends StatelessWidget {
  final int? seleccionado;
  final ValueChanged<int> onSeleccion;

  const CaritasAnimo({
    super.key,
    required this.seleccionado,
    required this.onSeleccion,
  });

  static const iconos = [
    Icons.sentiment_very_satisfied,
    Icons.sentiment_satisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_very_dissatisfied,
  ];
  static const etiquetas = ['Muy bien', 'Bien', 'Regular', 'Mal', 'Muy mal'];
  static const colores = [
    ColoresNana.ok,
    ColoresNana.azul,
    Color(0xFF6B6485),
    ColoresNana.alerta,
    Color(0xFFB3261E),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final activa = seleccionado == i;
        return Expanded(
          child: Semantics(
            button: true,
            selected: activa,
            label: etiquetas[i],
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSeleccion(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: activa
                      ? colores[i].withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      iconos[i],
                      size: activa ? 50 : 42,
                      color: activa ? colores[i] : const Color(0xFFB9B2CC),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etiquetas[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                        color: activa ? colores[i] : ColoresNana.tinta,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}