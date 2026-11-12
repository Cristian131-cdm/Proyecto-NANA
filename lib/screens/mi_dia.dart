import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/lector.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/icono_nana.dart';

// Escucha medicinas, rutinas y registros de hoy y arma el día con ellos.
class ConDia extends StatefulWidget {
  final String folio;
  final Widget Function(List<Actividad> dia, int? animo) builder;

  const ConDia({super.key, required this.folio, required this.builder});

  @override
  State<ConDia> createState() => _ConDiaState();
}

class _ConDiaState extends State<ConDia> {
  late final _meds = Servicios.repo.medicamentos(widget.folio);
  late final _hoy = Servicios.repo.registrosDeHoy(widget.folio);
  late final _rutinas = Servicios.repo.rutinas(widget.folio);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Rutina>>(
        stream: _rutinas,
        builder: (context, rutinas) => StreamBuilder<List<Registro>>(
          stream: _hoy,
          builder: (context, regs) {
            final hoy = regs.data ?? const <Registro>[];
            final animos = hoy.where((r) => r.tipo == TipoActividad.animo);
            return widget.builder(
              diaDelAdulto(
                meds: meds.data ?? const [],
                hoy: hoy,
                otras: rutinasDeHoy(
                  rutinas.data ?? const [],
                  Servicios.reloj(),
                ),
                ahora: Servicios.reloj(),
              ),
              animos.isEmpty ? null : animos.last.valor,
            );
          },
        ),
      ),
    );
  }
}

// "Ver todo mi día": la lista completa, para quien sí la quiere ver.
class MiDia extends StatefulWidget {
  final String folio;
  final ValueChanged<Actividad> onHecha;
  final ValueChanged<Actividad> onAbrir;

  const MiDia({
    super.key,
    required this.folio,
    required this.onHecha,
    required this.onAbrir,
  });

  @override
  State<MiDia> createState() => _MiDiaState();
}

class _MiDiaState extends State<MiDia> {
  // Lo último que se mostró, para que NANA lo lea.
  String _texto = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo mi día'),
        actions: [
          BotonLeeme(texto: () => _texto, color: ColoresNana.morado),
          const SizedBox(width: 8),
        ],
      ),
      body: ConDia(
        folio: widget.folio,
        builder: (dia, _) {
          _texto = textoMiDia(dia);
          return LeerAlAbrir(
            texto: () => _texto,
            listo: dia.isNotEmpty,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                for (final a in dia)
                  _FilaDia(
                    actividad: a,
                    onHecha: () => widget.onHecha(a),
                    onAbrir: () => widget.onAbrir(a),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilaDia extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback onHecha;
  final VoidCallback onAbrir;

  const _FilaDia({
    required this.actividad,
    required this.onHecha,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final estado = actividad.estado;
    final hecha = estado == EstadoActividad.hecha;
    final ahora = estado == EstadoActividad.ahora;
    final apagada = estado == EstadoActividad.pendiente;
    final queEs = hecha
        ? 'listo'
        : ahora
        ? 'toca ahora'
        : 'más tarde';

    final fila = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ahora
              ? ColoresNana.morado
              : hecha
              ? ColoresNana.okClaro
              : ColoresNana.moradoClaro,
          width: ahora ? 3 : 2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: hecha
                ? ColoresNana.okClaro
                : ahora
                ? ColoresNana.moradoClaro
                : const Color(0xFFF2F0F7),
            child: hecha
                ? Icon(Icons.check, size: 28, color: estado.color)
                : IconoActividad(
                    actividad.tipo,
                    tamano: 28,
                    color: estado.color,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${actividad.titulo} · ${actividad.hora}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: apagada
                        ? const Color(0xFF6B6485)
                        : ColoresNana.tinta,
                  ),
                ),
                Text(
                  hecha
                      ? 'Listo'
                      : ahora
                      ? 'Toca ahora · ${actividad.detalle}'
                      : actividad.detalle,
                  style: TextStyle(
                    fontSize: 16,
                    color: ahora ? ColoresNana.morado : const Color(0xFF6B6485),
                  ),
                ),
              ],
            ),
          ),
          if (ahora) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: Semantics(
                button: true,
                label: 'Marcar ${actividad.titulo} como hecho',
                excludeSemantics: true,
                child: FilledButton(
                  onPressed: onHecha,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.morado,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Ya'),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      label: '${actividad.titulo}, ${actividad.hora}, $queEs',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        // Tocar lo que toca ahora abre el recordatorio a pantalla completa.
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: ahora ? onAbrir : null,
            child: fila,
          ),
        ),
      ),
    );
  }
}
