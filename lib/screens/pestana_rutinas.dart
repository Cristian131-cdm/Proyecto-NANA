import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../models/actividad.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';

class PestanaRutinas extends StatelessWidget {
  const PestanaRutinas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => avisoPendiente(context),
        backgroundColor: ColoresNana.morado,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar', style: TextStyle(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          const Text(
            'NANA le recuerda estas cosas a lo largo del día.',
            style: TextStyle(fontSize: 16, color: Color(0xFF6B6485)),
          ),
          const TituloSeccion('Comidas'),
          ..._de(context, TipoActividad.comida),
          const TituloSeccion('Moverse'),
          ..._de(context, TipoActividad.ejercicio),
        ],
      ),
    );
  }

  List<Widget> _de(BuildContext context, TipoActividad tipo) {
    return DatosEjemplo.rutinas
        .where((r) => r.tipo == tipo)
        .map((r) => TarjetaDato(
              icono: r.tipo.icono,
              titulo: '${r.titulo} · ${r.hora}',
              subtitulo: r.detalle,
              color: tipo == TipoActividad.comida
                  ? ColoresNana.ok
                  : ColoresNana.azul,
              onTap: () => avisoPendiente(context),
            ))
        .toList();
  }
}
