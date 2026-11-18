import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import 'caritas_animo.dart';
import 'icono_nana.dart';

// La tarjeta grande del inicio del adulto: una sola cosa a la vez.
// Qué muestra lo decide queToca() en core/dia.dart.
class TarjetaAhora extends StatelessWidget {
  final QueToca que;
  final Actividad? actividad;
  final int? animo;
  final VoidCallback onHecha;
  final VoidCallback onAbrir;
  final ValueChanged<int> onAnimo;

  const TarjetaAhora({
    super.key,
    required this.que,
    required this.actividad,
    required this.animo,
    required this.onHecha,
    required this.onAbrir,
    required this.onAnimo,
  });

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    return switch (que) {
      QueToca.actividad when a != null => _Actividad(
        actividad: a,
        yaToca: true,
        onHecha: onHecha,
        onAbrir: onAbrir,
      ),
      QueToca.siguiente when a != null => _Actividad(
        actividad: a,
        yaToca: false,
        onHecha: onHecha,
        onAbrir: onAbrir,
      ),
      QueToca.animo => _Marco(
        borde: ColoresNana.lila,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: const Row(
                children: [
                  Icon(Icons.mood, color: ColoresNana.morado, size: 34),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿Cómo te sientes?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CaritasAnimo(seleccionado: animo, onSeleccion: onAnimo),
          ],
        ),
      ),
      _ => Semantics(
        container: true,
        label: 'Todo listo por ahora',
        excludeSemantics: true,
        child: const _Marco(
          borde: ColoresNana.okClaro,
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: ColoresNana.okClaro,
                child: Icon(Icons.check, color: ColoresNana.ok, size: 40),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Todo listo por ahora 💜',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    };
  }
}

class _Marco extends StatelessWidget {
  final Color borde;
  final Widget child;
  const _Marco({required this.borde, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: borde, width: 3),
    ),
    child: child,
  );
}

class _Actividad extends StatelessWidget {
  final Actividad actividad;
  final bool yaToca; // false: es "lo que sigue", más tarde
  final VoidCallback onHecha;
  final VoidCallback onAbrir;

  const _Actividad({
    required this.actividad,
    required this.yaToca,
    required this.onHecha,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final medicina = actividad.tipo == TipoActividad.medicina;
    // Una sola palabra: si ya toca o si es lo siguiente.
    final cuando = yaToca ? 'Ahora' : 'Después';
    return Semantics(
      container: true,
      label: '${actividad.titulo}, ${actividad.hora}, ${cuando.toLowerCase()}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          // Tocar lo que ya toca abre el recordatorio a pantalla completa.
          onTap: yaToca ? onAbrir : null,
          child: _Marco(
            borde: yaToca ? ColoresNana.morado : ColoresNana.moradoClaro,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: ColoresNana.moradoClaro,
                      child: IconoActividad(
                        actividad.tipo,
                        color: ColoresNana.morado,
                        tamano: 38,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                actividad.hora,
                                style: const TextStyle(
                                  fontSize: 34,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                  color: ColoresNana.morado,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: yaToca
                                      ? ColoresNana.morado
                                      : ColoresNana.moradoClaro,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  cuando,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: yaToca
                                        ? Colors.white
                                        : ColoresNana.morado,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            actividad.titulo,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: onHecha,
                    icon: const Icon(Icons.check, size: 30),
                    label: Text(medicina ? 'Ya me la tomé' : 'Ya lo hice'),
                    style: FilledButton.styleFrom(
                      backgroundColor: yaToca
                          ? ColoresNana.ok
                          : ColoresNana.moradoClaro,
                      foregroundColor: yaToca
                          ? Colors.white
                          : ColoresNana.morado,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
