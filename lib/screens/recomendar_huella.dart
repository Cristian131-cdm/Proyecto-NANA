import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../widgets/aviso.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'candado.dart';

// Después de entrar por primera vez, ofrece la huella una sola vez.
// Si el celular no tiene ningún bloqueo, se salta.
Future<void> entrarRecomendandoHuella(
  BuildContext context,
  Widget destino,
) async {
  final ofrecer =
      !Ajustes.huellaOfrecida.value &&
      await Servicios.biometria.disponible();
  if (!context.mounted) return;
  entrarA(context, ofrecer ? RecomendarHuella(destino: destino) : destino);
}

class RecomendarHuella extends StatelessWidget {
  final Widget destino;
  const RecomendarHuella({super.key, required this.destino});

  Future<void> _activar(BuildContext context) async {
    final ok = await Servicios.biometria.autenticar(motivoHuella);
    Ajustes.huellaOfrecida.value = true;
    if (ok) Ajustes.huellaActivada.value = true;
    if (!context.mounted) return;
    entrarA(context, destino);
    if (ok) mostrarAviso(context, 'Listo, NANA se abre con tu huella');
  }

  void _ahoraNo(BuildContext context) {
    Ajustes.huellaOfrecida.value = true;
    entrarA(context, destino);
  }

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      titulo: '¿Quieres entrar con tu huella?',
      subtitulo:
          'Así solo tú abres NANA. Si no tienes huella, sirve tu cara o el '
          'PIN de tu celular. Cuando suene tu medicina no te la va a pedir.',
      children: [
        const Icon(Icons.fingerprint, size: 96, color: ColoresNana.morado),
        const SizedBox(height: 24),
        BotonPrincipal(
          texto: 'Sí, activarla',
          onPressed: () => _activar(context),
        ),
        const SizedBox(height: 16),
        BotonSecundario(texto: 'Ahora no', onPressed: () => _ahoraNo(context)),
        const SizedBox(height: 12),
        const Text(
          'Puedes cambiarlo cuando quieras en Aa · Lectura y accesibilidad.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
