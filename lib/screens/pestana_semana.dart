import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dia.dart';
import '../core/reporte_pdf.dart';
import '../core/semana.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/aviso.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/tarjeta_dato.dart';
import '../widgets/icono_nana.dart';

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
    final t = TotalesSemana(dias);
    final total = t.tomas;
    final posibles = t.posibles;
    final faltas = t.faltas;
    final mal = t.mal;
    final sinDatos =
        total == 0 && dias.every((d) => d.animo == null && d.movimiento == 0);
    final todoBien = posibles > 0 && faltas.isEmpty && mal.isEmpty;

    String lista(List<String> xs) => xs.length <= 1
        ? xs.join()
        : '${xs.sublist(0, xs.length - 1).join(', el ')} y el ${xs.last}';

    final importante = [
      if (posibles == 0) 'Sin medicinas registradas',
      if (posibles > 0 && faltas.isEmpty) 'Todas las medicinas a tiempo',
      if (faltas.isNotEmpty) 'Faltó alguna medicina el ${lista(faltas)}',
      if (mal.isNotEmpty)
        'Dijo sentirse mal el ${lista([for (final d in mal) d.nombre])}',
      if (t.movimientoPosible > 0)
        'Se movió ${t.movimiento} de ${t.movimientoPosible} veces',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'La semana de $adulto',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ColoresNana.morado,
          ),
        ),
        Text(
          rangoSemana(dias),
          style: const TextStyle(fontSize: 16, color: ColoresNana.tintaSuave),
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
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          decoration: _caja,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (posibles > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$total',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: faltas.isEmpty
                                ? ColoresNana.ok
                                : ColoresNana.alerta,
                          ),
                        ),
                        TextSpan(
                          text: ' de $posibles a tiempo',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _FilaSemana(
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
                              d.letra,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _CirculoDia(dia: d),
                          ],
                        ),
                      ),
                    ),
                ],
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: todoBien ? ColoresNana.okClaro : ColoresNana.alertaClaro,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final linea in importante)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    linea,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: todoBien ? ColoresNana.ok : ColoresNana.tinta,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toca un día para ver qué se anotó',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: ColoresNana.tintaSuave),
        ),
        const SizedBox(height: 16),
        _BotonReporte(adulto: adulto, dias: dias),
      ],
    );
  }

  static final _caja = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: ColoresNana.moradoClaro),
  );
}

// Arma el PDF de la semana y abre la hoja de compartir del celular.
class _BotonReporte extends StatefulWidget {
  final String adulto;
  final List<DiaSemana> dias;
  const _BotonReporte({required this.adulto, required this.dias});

  @override
  State<_BotonReporte> createState() => _BotonReporteState();
}

class _BotonReporteState extends State<_BotonReporte> {
  bool _ocupado = false;

  Future<void> _mandar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final hoy = Servicios.reloj();
      final bytes = await reporteSemanaPdf(
        widget.adulto,
        widget.dias,
        generado: hoy,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: nombreReporte(widget.adulto, hoy),
            ),
          ],
          // Algunas apps ignoran `name` de XFile y usan este.
          fileNameOverrides: [nombreReporte(widget.adulto, hoy)],
          text: resumenSemana(widget.adulto, widget.dias),
          subject: 'Reporte semanal de ${widget.adulto}',
        ),
      );
    } catch (_) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo armar el reporte. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => BotonSecundario(
    icono: _ocupado ? Icons.hourglass_top : Icons.picture_as_pdf,
    texto: _ocupado ? 'Armando el resumen…' : 'Mandar el resumen',
    onPressed: _mandar,
  );
}

class _CirculoDia extends StatelessWidget {
  final DiaSemana dia;
  const _CirculoDia({required this.dia});

  @override
  Widget build(BuildContext context) {
    final d = dia;
    final sinMedicinas = d.posibles == 0;
    final color = sinMedicinas
        ? ColoresNana.gris
        : d.completo
        ? ColoresNana.ok
        : ColoresNana.alerta;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: d.completo ? ColoresNana.ok : Colors.white,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(
        sinMedicinas
            ? Icons.remove
            : d.completo
            ? Icons.check
            : Icons.priority_high,
        size: 22,
        color: d.completo ? Colors.white : color,
      ),
    );
  }
}

// Cada día conserva un ancho táctil legible, incluso con letra grande.
class _FilaSemana extends StatelessWidget {
  final List<Widget> children;
  const _FilaSemana({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final escala = MediaQuery.textScalerOf(context).scale(16) / 16;
      final minimo = children.length * 64.0 * escala;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minimo > limites.maxWidth ? minimo : limites.maxWidth,
          child: Row(children: children),
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
                  child: IconoActividad(r.tipo, color: ColoresNana.morado),
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
