import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dia.dart';
import '../core/semana.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/tarjeta_dato.dart';

// Los últimos 7 días, calculados con lo que se anotó de verdad.
class PestanaSemana extends StatefulWidget {
  final String adulto;
  final String folio;
  const PestanaSemana({super.key, required this.adulto, required this.folio});

  @override
  State<PestanaSemana> createState() => _PestanaSemanaState();
}

class _PestanaSemanaState extends State<PestanaSemana> {
  late final _meds = Servicios.repo.medicamentos(widget.folio);
  late final _rutinas = Servicios.repo.rutinas(widget.folio);
  late final _registros = Servicios.repo.registrosDesde(
    widget.folio,
    DateUtils.dateOnly(Servicios.reloj()).subtract(const Duration(days: 6)),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Rutina>>(
        stream: _rutinas,
        builder: (context, rutinas) => StreamBuilder<List<Registro>>(
          stream: _registros,
          builder: (context, regs) => VistaSemana(
            adulto: widget.adulto,
            dias: semana(
              meds: meds.data ?? const [],
              rutinas: rutinas.data ?? const [],
              registros: regs.data ?? const [],
              hoy: Servicios.reloj(),
            ),
          ),
        ),
      ),
    );
  }
}

class VistaSemana extends StatelessWidget {
  final String adulto;
  final List<DiaSemana> dias;
  const VistaSemana({super.key, required this.adulto, required this.dias});

  @override
  Widget build(BuildContext context) {
    final total = dias.fold(0, (a, d) => a + d.tomas);
    final posibles = dias.fold(0, (a, d) => a + d.posibles);
    final faltas = [
      for (final d in dias)
        if (d.posibles > 0 && !d.completo) d.nombre,
    ];
    final mal = [
      for (final d in dias)
        if (d.horaMal != null) d,
    ];
    final movimiento = dias.fold(0, (a, d) => a + d.movimiento);
    final movimientoPosible = dias.fold(0, (a, d) => a + d.movimientoPosible);
    final maxPorDia = dias.fold(1, (a, d) => d.posibles > a ? d.posibles : a);
    final sinDatos =
        total == 0 && dias.every((d) => d.animo == null && d.movimiento == 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        CabeceraCuidador(
          titulo: 'La semana de $adulto',
          detalle: rangoSemana(dias),
          icono: Icons.bar_chart_rounded,
        ),
        if (sinDatos) ...[
          const SizedBox(height: 12),
          TarjetaDato(
            icono: Icons.hourglass_empty,
            titulo: 'Todavía no hay datos de esta semana',
            subtitulo:
                'Cuando $adulto confirme medicinas o diga cómo se siente, '
                'aquí verás su semana.',
          ),
        ],
        const TituloSeccion('Medicinas a tiempo'),
        // Sin altura fija: la caja crece con la letra. Con una altura fija,
        // la letra grande del celular desbordaba las columnas.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          decoration: _caja,
          child: _FilaSemana(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in dias)
                Expanded(
                  child: _DiaTocable(
                    dia: d,
                    etiqueta:
                        '${d.nombre}: ${d.tomas} de ${d.posibles} medicinas',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${d.tomas}/${d.posibles}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ColoresNana.tintaSuave,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // La barra sube al abrir la pestaña.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: d.tomas / maxPorDia),
                          duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : 600,
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Container(
                            width: 26,
                            height: 4 + 86.0 * v,
                            decoration: BoxDecoration(
                              color: d.completo
                                  ? ColoresNana.lila
                                  : ColoresNana.alerta,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.letra,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const TituloSeccion('Cómo se sintió'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: _caja,
          child: _FilaSemana(
            children: [
              for (final d in dias)
                Expanded(
                  child: _DiaTocable(
                    dia: d,
                    etiqueta: d.animo == null
                        ? '${d.nombre}: sin dato'
                        : '${d.nombre}: ${CaritasAnimo.etiquetas[d.animo!]}',
                    child: Column(
                      children: [
                        d.animo == null
                            ? const Icon(
                                Icons.remove,
                                size: 32,
                                color: ColoresNana.gris,
                              )
                            : Icon(
                                CaritasAnimo.iconos[d.animo!],
                                size: 32,
                                color: CaritasAnimo.colores[d.animo!],
                              ),
                        const SizedBox(height: 4),
                        Text(
                          d.letra,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const TituloSeccion('Lo importante'),
        if (posibles == 0)
          const TarjetaDato(
            icono: Icons.medication,
            titulo: 'Sin medicinas registradas',
            subtitulo: 'Agrégalas en la pestaña Medicinas',
          )
        else
          TarjetaDato(
            icono: Icons.medication,
            titulo: '$total de $posibles tomas',
            subtitulo: faltas.isEmpty
                ? 'Todas a tiempo 💜'
                : 'Faltaron el ${faltas.join(', el ')}',
            color: faltas.isEmpty ? ColoresNana.ok : ColoresNana.alerta,
          ),
        for (final d in mal)
          TarjetaDato(
            icono: Icons.sentiment_dissatisfied,
            titulo: 'El ${d.nombre} dijo que se sentía mal',
            subtitulo: 'A las ${horaDe(d.horaMal!)}',
            color: ColoresNana.alerta,
          ),
        if (movimientoPosible > 0)
          TarjetaDato(
            icono: Icons.directions_walk,
            titulo: 'Se movió $movimiento de $movimientoPosible veces',
            subtitulo: 'Según sus rutinas de actividad',
            color: ColoresNana.azul,
          ),
        const SizedBox(height: 12),
        BotonSecundario(
          icono: Icons.share,
          texto: 'Mandar resumen a la familia',
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: resumenSemana(adulto, dias)),
          ),
        ),
      ],
    );
  }

  static final _caja = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: ColoresNana.moradoClaro),
  );
}

// Cada día conserva un ancho táctil legible, incluso con letra grande.
class _FilaSemana extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  const _FilaSemana({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final escala = MediaQuery.textScalerOf(context).scale(16) / 16;
      final minimo = children.length * 64.0 * escala;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minimo > limites.maxWidth ? minimo : limites.maxWidth,
          child: Row(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      );
    },
  );
}

// Cada columna de la semana se puede tocar para ver lo que pasó ese día.
class _DiaTocable extends StatelessWidget {
  final DiaSemana dia;
  final String etiqueta;
  final Widget child;
  const _DiaTocable({
    required this.dia,
    required this.etiqueta,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$etiqueta. Toca para ver el día',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => mostrarDetalleDia(context, dia),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: child,
        ),
      ),
    );
  }
}

String tituloDia(DiaSemana d) {
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final nombre = '${d.nombre[0].toUpperCase()}${d.nombre.substring(1)}';
  return '$nombre ${d.fecha.day} de ${meses[d.fecha.month - 1]}';
}

// Hoja con lo que pasó ese día: medicinas, ánimo y cada cosa anotada.
Future<void> mostrarDetalleDia(BuildContext context, DiaSemana d) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            Text(
              tituloDia(d),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.medication,
                    color: ColoresNana.morado,
                  ),
                  label: Text(
                    d.posibles == 0
                        ? 'Sin medicinas'
                        : 'Medicinas: ${d.tomas} de ${d.posibles}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    d.animo == null
                        ? Icons.mood
                        : CaritasAnimo.iconos[d.animo!],
                    color: d.animo == null
                        ? ColoresNana.gris
                        : CaritasAnimo.colores[d.animo!],
                  ),
                  label: Text(
                    d.animo == null
                        ? 'Ánimo: sin dato'
                        : 'Ánimo: ${CaritasAnimo.etiquetas[d.animo!]}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const TituloSeccion('Lo que se anotó'),
            if (d.registros.isEmpty)
              const Text(
                'Ese día no se anotó nada.',
                style: TextStyle(fontSize: 18, color: ColoresNana.tintaSuave),
              ),
            for (final r in d.registros)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: ColoresNana.moradoClaro,
                  child: Icon(r.tipo.icono, color: ColoresNana.morado),
                ),
                title: Text(queHizo(r), style: const TextStyle(fontSize: 18)),
                trailing: Text(
                  horaDe(r.fecha),
                  style: const TextStyle(
                    fontSize: 16,
                    color: ColoresNana.tintaSuave,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
