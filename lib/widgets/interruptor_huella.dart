import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/biometria.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../screens/candado.dart';
import 'aviso.dart';

// Interruptor para Ajustes. Para encenderlo pide la huella primero.
class InterruptorHuella extends StatelessWidget {
  const InterruptorHuella({super.key});

  Future<void> _cambiar(BuildContext context, bool encender) async {
    if (!encender) {
      Ajustes.huellaActivada.value = false;
      return;
    }
    if (await Servicios.biometria.autenticar(motivoHuella)) {
      Ajustes.huellaActivada.value = true;
    } else if (context.mounted) {
      mostrarAviso(context, 'No se activó. Intenta de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Servicios.biometria.disponible(),
      builder: (context, hay) {
        if (hay.data != true) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: Ajustes.huellaActivada,
          builder: (context, encendida, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(
              Icons.fingerprint,
              color: ColoresNana.morado,
              size: 30,
            ),
            title: const Text(
              'Entrar con huella',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'La pide si NANA estuvo cerrada $minutosParaBloquear minutos o más',
              style: const TextStyle(fontSize: 15),
            ),
            value: encendida,
            onChanged: (v) => _cambiar(context, v),
          ),
        );
      },
    );
  }
}
