import 'package:flutter/material.dart';

import '../core/permisos.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/demo.dart';
import '../models/adulto.dart';
import '../widgets/ajustes_texto.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_servidor_agente.dart';
import 'alta_adulto.dart';
import 'arranque.dart';
import 'como_va_la_prueba.dart';

// «Mis ajustes y cuenta» de quien cuida (pestaña Más): su letra, colores,
// «Oye NANA» y huella, y lo de su cuenta (antes en el menú «Mi cuenta»).
class MisAjustes extends StatefulWidget {
  final Adulto adulto;
  const MisAjustes({super.key, required this.adulto});

  @override
  State<MisAjustes> createState() => _MisAjustesState();
}

class _MisAjustesState extends State<MisAjustes> {
  // Solo el equipo ve «Cómo va la prueba».
  bool _veEstudio = false;

  @override
  void initState() {
    super.initState();
    Servicios.repo.puedeVerEstudio().then((si) {
      if (mounted && si) setState(() => _veEstudio = true);
    }).ignore();
  }

  void _ir(Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  Future<void> _demo() async {
    final a = widget.adulto;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cargar datos de demostración?'),
        content: Text(
          'Se agregan rutinas, una receta, dos citas y una semana de '
          'ejemplo para ${a.nombre}. No se borra nada de lo que ya '
          'tiene y el día de hoy no se toca.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cargar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    final n = await cargarDemo(Servicios.repo, a.folio, Servicios.reloj());
    if (mounted) {
      mostrarAviso(
        context,
        n == 0 ? 'Ya tenía los datos de demostración' : 'Listo, datos cargados',
      );
    }
  }

  Future<void> _salir() => salirDeNana(context);

  @override
  Widget build(BuildContext context) {
    final a = widget.adulto;
    final permisos = Permisos.de(a, Servicios.repo.uid, Servicios.reloj());
    return Scaffold(
      appBar: AppBar(title: const Text('Mis ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const AjustesLecturaCuidador(),
          const SizedBox(height: 20),
          const Text(
            'Mi cuenta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GrupoRenglones(
            children: [
              Renglon(
                icono: Icons.person_add_alt,
                texto: 'Cuidar a otra persona',
                onTap: () => _ir(const AltaAdulto()),
              ),
              if (permisos.borrarDatos)
                Renglon(
                  icono: Icons.auto_awesome_outlined,
                  texto: 'Cargar datos de demostración',
                  onTap: _demo,
                ),
              if (_veEstudio)
                Renglon(
                  icono: Icons.insights_outlined,
                  texto: 'Cómo va la prueba',
                  onTap: () => _ir(const ComoVaLaPrueba()),
                ),
            ],
          ),
          // Para pruebas y la demo: la IP de la laptop donde corre el agente
          // («Pregúntale a NANA» con IA). Es el mismo ajuste del adulto.
          const SizedBox(height: 24),
          const CampoServidorAgente(),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _salir,
              icon: const Icon(Icons.logout, size: 26),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresNana.alerta,
                side: const BorderSide(color: ColoresNana.alerta, width: 2),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta blanca con renglones separados por una línea (pestaña Más y
// Mis ajustes).
class GrupoRenglones extends StatelessWidget {
  final List<Widget> children;
  const GrupoRenglones({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFDDD6F3), width: 2),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: ColoresNana.moradoClaro),
            children[i],
          ],
        ],
      ),
    );
  }
}

// Un renglón grande: ícono, una o dos palabras y flechita.
class Renglon extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final String? nota; // a la derecha, chiquita: «Solo ver»
  const Renglon({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.nota,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icono, color: ColoresNana.morado, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (nota != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    nota!,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 15,
                      color: ColoresNana.tintaSuave,
                    ),
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: ColoresNana.tintaSuave),
          ],
        ),
      ),
    );
  }
}
