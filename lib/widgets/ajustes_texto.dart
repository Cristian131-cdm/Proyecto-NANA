import 'package:flutter/material.dart';
import '../core/ajustes.dart';
import '../core/tema.dart';

void mostrarAjustesTexto(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder<double>(
          valueListenable: Ajustes.escalaTexto,
          builder: (context, actual, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tamaño de letra',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Elige el que te resulte más cómodo',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  children: opciones.map((o) {
                    final activa = actual == o.$1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                            child: Column(
                              children: [
                                Text('Aa',
                                    style: TextStyle(
                                        fontSize: o.$3,
                                        fontWeight: FontWeight.bold,
                                        color: ColoresNana.morado)),
                                const SizedBox(height: 4),
                                Text(o.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: activa
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}