import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../models/adulto.dart';
import '../widgets/con_encargado.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'panel_cuidador.dart';

// Lo primero que ve un familiar al unirse con una invitación: a quién
// acompaña, quién lo invitó y qué puede hacer (y qué no) en NANA.
class BienvenidaFamiliar extends StatelessWidget {
  final Adulto adulto;
  const BienvenidaFamiliar({super.key, required this.adulto});

  @override
  Widget build(BuildContext context) {
    final nombre = adulto.nombre;
    return ConEncargado(
      folio: adulto.folio,
      creadoPor: adulto.creadoPor,
      builder: (encargado) => PantallaPaso(
        titulo: 'Ya acompañas a $nombre',
        subtitulo: encargado == ConEncargado.sinNombre
            ? null
            : 'Te invitó $encargado, que la cuida.',
        children: [
          const Text(
            'Puedes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _Puedes(Icons.home_outlined, 'Ver cómo va su día'),
          const _Puedes(Icons.notifications_outlined, 'Recibir sus alertas'),
          const _Puedes(Icons.call_outlined, 'Llamarle'),
          const _Puedes(
            Icons.medication_outlined,
            'Marcar su medicina si estás con ella',
          ),
          const SizedBox(height: 16),
          AvisoCandado(
            'Sus medicinas, rutinas y su expediente solo los cambia '
            '${encargado == ConEncargado.sinNombre ? 'quien la dio de alta' : encargado}.',
          ),
          const SizedBox(height: 28),
          BotonPrincipal(
            texto: 'Empezar',
            onPressed: () => entrarA(context, const PanelCuidador()),
          ),
        ],
      ),
    );
  }
}

class _Puedes extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Puedes(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icono, color: ColoresNana.morado, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 20))),
        ],
      ),
    );
  }
}
