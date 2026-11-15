import 'package:flutter/material.dart';

import '../core/medicion.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../widgets/tarjeta_dato.dart';

// Para el equipo: en qué pantallas se atora más la gente durante la prueba.
// Solo la abre quien está en la lista de administradores del estudio.
class ComoVaLaPrueba extends StatefulWidget {
  const ComoVaLaPrueba({super.key});

  @override
  State<ComoVaLaPrueba> createState() => _ComoVaLaPruebaState();
}

class _ComoVaLaPruebaState extends State<ComoVaLaPrueba> {
  late Future<List<EventoUso>> _eventos = Servicios.repo.usoReciente();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cómo va la prueba'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () =>
                setState(() => _eventos = Servicios.repo.usoReciente()),
          ),
        ],
      ),
      body: FutureBuilder<List<EventoUso>>(
        future: _eventos,
        builder: (context, snap) {
          if (snap.hasError) {
            final e = snap.error;
            return _Mensaje(
              e is ErrorNana ? e.mensaje : 'No se pudo leer el estudio.',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = resumirUso(snap.data!);
          if (r.eventos == 0) {
            return const _Mensaje(
              'Todavía no hay datos. Prende "Ayudar a mejorar NANA" en '
              'Familia y alertas y usa la app un rato.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                '${r.eventos} eventos anónimos. Arriba, las pantallas donde '
                'más se regresan o les sale un error.',
                style: const TextStyle(
                  fontSize: 16,
                  color: ColoresNana.tintaSuave,
                ),
              ),
              const TituloSeccion('Dónde se atoran'),
              for (final u in r.pantallas)
                TarjetaDato(
                  icono: u.tropiezos >= 0.5
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: u.tropiezos >= 0.5
                      ? ColoresNana.alerta
                      : ColoresNana.ok,
                  titulo: u.pantalla,
                  subtitulo:
                      '${u.visitas} visitas · ${u.promedio} s en promedio · '
                      '${u.regresos} regresos · ${u.errores} errores',
                ),
              const TituloSeccion('Tareas terminadas'),
              if (r.tareas.isEmpty)
                const Text(
                  'Ninguna todavía.',
                  style: TextStyle(fontSize: 18, color: ColoresNana.tintaSuave),
                ),
              for (final t in r.tareas.entries)
                TarjetaDato(
                  icono: Icons.task_alt,
                  titulo: nombresDeTareas[t.key] ?? t.key,
                  subtitulo: '${t.value} ${t.value == 1 ? 'vez' : 'veces'}',
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  const _Mensaje(this.texto);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18),
      ),
    ),
  );
}
