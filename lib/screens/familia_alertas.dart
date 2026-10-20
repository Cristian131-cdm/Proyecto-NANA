import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';

class FamiliaAlertas extends StatelessWidget {
  final String adulto;
  const FamiliaAlertas({super.key, required this.adulto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familia y alertas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          TituloSeccion('Quiénes cuidan a $adulto'),
          for (final (i, f) in DatosEjemplo.familia.indexed)
            TarjetaDato(
              icono: Icons.person,
              titulo: i == 0 ? 'Tú (${f.$1}) · ${f.$2}' : '${f.$1} · ${f.$2}',
              subtitulo: f.$3,
              onTap: () => avisoPendiente(context),
            ),
          BotonSecundario(
            icono: Icons.person_add_alt_1,
            texto: 'Invitar a alguien con código',
            onPressed: () => avisoPendiente(context),
          ),
          const TituloSeccion('¿Cuándo te aviso?'),
          TarjetaDato(
            icono: Icons.medication,
            titulo: 'Medicina sin confirmar',
            subtitulo: 'Si se pasa la hora y no la confirma',
            color: ColoresNana.alerta,
            onTap: () => avisoPendiente(context),
          ),
          TarjetaDato(
            icono: Icons.schedule,
            titulo: 'Sin noticias',
            subtitulo: 'Si pasan 12 horas sin ningún registro',
            color: ColoresNana.alerta,
            onTap: () => avisoPendiente(context),
          ),
          TarjetaDato(
            icono: Icons.notifications_active,
            titulo: 'Cuando pide ayuda',
            subtitulo: 'Siempre, al momento',
            color: ColoresNana.alerta,
            onTap: () => avisoPendiente(context),
          ),
          const TituloSeccion('Privacidad'),
          TarjetaDato(
            icono: Icons.lock_outline,
            titulo: 'Qué datos se guardan',
            subtitulo: 'Y quién los puede ver',
            onTap: () => avisoPendiente(context),
          ),
        ],
      ),
    );
  }
}
