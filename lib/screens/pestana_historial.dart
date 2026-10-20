import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';

class PestanaHistorial extends StatelessWidget {
  final String adulto;
  const PestanaHistorial({super.key, required this.adulto});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Lo que indicó el médico de $adulto',
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B6485))),
        const TituloSeccion('Recetas'),
        for (final r in DatosEjemplo.recetas)
          TarjetaDato(
            icono: Icons.description_outlined,
            titulo: '${r.$1} · ${r.$2}',
            subtitulo: r.$3,
            onTap: () => avisoPendiente(context),
          ),
        BotonSecundario(
          icono: Icons.photo_camera_outlined,
          texto: 'Agregar receta',
          onPressed: () => avisoPendiente(context),
        ),
        const TituloSeccion('Datos de salud'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in DatosEjemplo.padecimientos)
              Chip(
                label: Text(p, style: const TextStyle(fontSize: 16)),
                backgroundColor: ColoresNana.moradoClaro,
                side: BorderSide.none,
                shape: const StadiumBorder(),
              ),
            for (final a in DatosEjemplo.alergias)
              Chip(
                avatar: const Icon(Icons.warning_amber_rounded,
                    color: ColoresNana.alerta, size: 20),
                label: Text('Alergia: $a',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColoresNana.alerta)),
                backgroundColor: ColoresNana.alertaClaro,
                side: const BorderSide(color: ColoresNana.alerta),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const TituloSeccion('Próximas citas'),
        for (final c in DatosEjemplo.citas)
          TarjetaDato(
            icono: Icons.event,
            titulo: c.$1,
            subtitulo: '${c.$2} · ${c.$3}',
            color: ColoresNana.azul,
          ),
        const SizedBox(height: 16),
        const Text(
          'NANA solo guarda lo que indicó un profesional de la salud.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B6485)),
        ),
      ],
    );
  }
}
