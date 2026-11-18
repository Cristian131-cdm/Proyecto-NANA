import 'package:flutter/material.dart';

import '../core/semana.dart' show fechaLarga, horaDe, nombresDias;
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/receta.dart';
import '../models/salud.dart';
import 'pestana_historial.dart';
import 'pestana_mas.dart' show ConBarra;

// «Su expediente» en corto: tres tarjetas (datos de salud, recetas y la
// próxima cita). Cada una abre el expediente completo, donde se agrega o
// se cambia todo.
class ResumenExpediente extends StatefulWidget {
  final String adulto;
  final String folio;
  final bool puedeEditar;

  const ResumenExpediente({
    super.key,
    required this.adulto,
    required this.folio,
    this.puedeEditar = true,
  });

  @override
  State<ResumenExpediente> createState() => _ResumenExpedienteState();
}

class _ResumenExpedienteState extends State<ResumenExpediente> {
  late final _salud = Servicios.repo.salud(widget.folio);
  late final _recetas = Servicios.repo.recetas(widget.folio);
  late final _citas = Servicios.repo.citas(widget.folio);

  void _abrirTodo() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ConBarra(
        titulo: 'Expediente de ${widget.adulto}',
        child: PestanaHistorial(
          adulto: widget.adulto,
          folio: widget.folio,
          puedeEditar: widget.puedeEditar,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Salud>(
      stream: _salud,
      builder: (context, salud) => StreamBuilder<List<Receta>>(
        stream: _recetas,
        builder: (context, recetas) => StreamBuilder<List<Cita>>(
          stream: _citas,
          builder: (context, citas) => _contenido(
            salud.data,
            recetas.data ?? const [],
            citas.data ?? const [],
          ),
        ),
      ),
    );
  }

  Widget _contenido(Salud? salud, List<Receta> recetas, List<Cita> citas) {
    final ahora = Servicios.reloj();
    final proxima =
        (citas.where((c) => c.fecha.isAfter(ahora)).toList()
              ..sort((a, b) => a.fecha.compareTo(b.fecha)))
            .firstOrNull;
    final ultima = (List.of(
      recetas,
    )..sort((a, b) => b.fecha.compareTo(a.fecha))).firstOrNull;
    final etiquetas = [
      ...?salud?.padecimientos,
      for (final a in salud?.alergias ?? const <String>[]) 'Alergia: $a',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Tarjeta(
          icono: Icons.favorite_border,
          titulo: 'Datos de salud',
          onTap: _abrirTodo,
          child: etiquetas.isEmpty
              ? const Text(
                  'Todavía no hay datos de salud',
                  style: TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in etiquetas)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: e.startsWith('Alergia')
                              ? ColoresNana.alertaClaro
                              : ColoresNana.moradoClaro,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: e.startsWith('Alergia')
                                ? ColoresNana.alerta
                                : ColoresNana.morado,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _Tarjeta(
          icono: Icons.description_outlined,
          titulo: 'Recetas',
          cuenta: recetas.length,
          onTap: _abrirTodo,
          child: Text(
            ultima == null
                ? 'Todavía no hay recetas'
                : 'La última: ${ultima.medico} · ${fechaLarga(ultima.fecha)}',
            style: const TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
          ),
        ),
        const SizedBox(height: 12),
        _Tarjeta(
          icono: Icons.event_outlined,
          titulo: 'Próxima cita',
          onTap: _abrirTodo,
          child: proxima == null
              ? const Text(
                  'No hay citas próximas',
                  style: TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proxima.especialidad,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ColoresNana.morado,
                      ),
                    ),
                    Text(
                      [
                        '${nombresDias[proxima.fecha.weekday - 1]} '
                            '${fechaLarga(proxima.fecha)}',
                        horaDe(proxima.fecha),
                        if (proxima.lugar.isNotEmpty) proxima.lugar,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 17,
                        color: ColoresNana.tintaSuave,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 60,
          child: OutlinedButton.icon(
            onPressed: _abrirTodo,
            icon: const Icon(Icons.folder_open, size: 26),
            label: Text(
              widget.puedeEditar ? 'Ver y agregar' : 'Ver todo el expediente',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresNana.morado,
              side: const BorderSide(color: ColoresNana.morado, width: 2),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Solo lo indicado por un profesional de la salud. Los familiares '
          'invitados no ven esta parte.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: ColoresNana.tintaSuave),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final int? cuenta;
  final VoidCallback onTap;
  final Widget child;

  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.onTap,
    required this.child,
    this.cuenta,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFDDD6F3), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: ColoresNana.morado, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (cuenta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ColoresNana.moradoClaro,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$cuenta',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ColoresNana.morado,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    color: ColoresNana.tintaSuave,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
