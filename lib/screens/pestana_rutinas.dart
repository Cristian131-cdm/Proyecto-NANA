import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/rutina.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';

const _nombresDias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

// Convierte los días elegidos (0 = lunes) en el texto que se ve en la tarjeta.
String textoDias(Set<int> dias) {
  final orden = dias.toList()..sort();
  if (orden.length == 7) return 'Todos los días';
  if (orden.length == 5 && orden.last == 4) return 'Lunes a viernes';
  final nombres = [
    for (final (i, d) in orden.indexed)
      i == 0 ? _nombresDias[d] : _nombresDias[d].toLowerCase(),
  ];
  if (nombres.length == 1) return nombres.first;
  return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
}

class PestanaRutinas extends StatefulWidget {
  final String folio;
  const PestanaRutinas({super.key, required this.folio});

  @override
  State<PestanaRutinas> createState() => _PestanaRutinasState();
}

class _PestanaRutinasState extends State<PestanaRutinas> {
  late final _rutinas = Servicios.repo.rutinas(widget.folio);

  void _abrirFormulario([Rutina? inicial]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioRutina(
        inicial: inicial,
        onGuardar: (r) {
          Servicios.repo.guardarRutina(widget.folio, r);
          mostrarAviso(context, 'Rutina guardada');
        },
        onEliminar: inicial == null
            ? null
            : () {
                Servicios.repo.borrarRutina(widget.folio, inicial.id!);
                mostrarAviso(context, 'Rutina eliminada');
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: ColoresNana.morado,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar', style: TextStyle(fontSize: 18)),
      ),
      body: StreamBuilder<List<Rutina>>(
        stream: _rutinas,
        builder: (context, snap) {
          final rutinas = snap.data ?? const <Rutina>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              const Text(
                'NANA le recuerda estas cosas a lo largo del día.',
                style: TextStyle(fontSize: 16, color: ColoresNana.tintaSuave),
              ),
              const TituloSeccion('Comidas'),
              ..._de(rutinas, TipoActividad.comida),
              const TituloSeccion('Moverse'),
              ..._de(rutinas, TipoActividad.ejercicio),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _de(List<Rutina> rutinas, TipoActividad tipo) {
    final deTipo = rutinas.where((r) => r.tipo == tipo).toList();
    if (deTipo.isEmpty) {
      return [
        Text(
          tipo == TipoActividad.comida
              ? 'Sin comidas todavía. Toca "Agregar".'
              : 'Sin actividades todavía. Toca "Agregar".',
          style: const TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
        ),
      ];
    }
    return [
      for (final r in deTipo)
        TarjetaDato(
          icono: tipo.icono,
          titulo: '${r.titulo} · ${horaCorta(r.hora)}',
          subtitulo: textoDias(r.dias),
          color: tipo == TipoActividad.comida
              ? ColoresNana.ok
              : ColoresNana.azul,
          onTap: () => _abrirFormulario(r),
        ),
    ];
  }
}

class FormularioRutina extends StatefulWidget {
  final Rutina? inicial;
  final ValueChanged<Rutina> onGuardar;
  final VoidCallback? onEliminar;

  const FormularioRutina({
    super.key,
    this.inicial,
    required this.onGuardar,
    this.onEliminar,
  });

  @override
  State<FormularioRutina> createState() => _FormularioRutinaState();
}

class _FormularioRutinaState extends State<FormularioRutina> {
  late final _nombre = TextEditingController(text: widget.inicial?.titulo);
  late TipoActividad _tipo = widget.inicial?.tipo ?? TipoActividad.comida;
  late TimeOfDay _hora =
      widget.inicial?.hora ?? const TimeOfDay(hour: 8, minute: 0);
  late final Set<int> _dias = Set.of(
    widget.inicial?.dias ?? const {0, 1, 2, 3, 4, 5, 6},
  );
  bool _intento = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  void _guardar() {
    setState(() => _intento = true);
    if (_nombre.text.trim().isEmpty || _dias.isEmpty) return;
    widget.onGuardar(
      Rutina(
        id: widget.inicial?.id,
        titulo: _nombre.text.trim(),
        tipo: _tipo,
        hora: _hora,
        dias: Set.of(_dias),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.inicial == null ? 'Nueva rutina' : 'Editar rutina',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Si es ejercicio, que sea lo indicado por su médico.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TipoActividad>(
              segments: const [
                ButtonSegment(
                  value: TipoActividad.comida,
                  icon: Icon(Icons.restaurant),
                  label: Text('Comida'),
                ),
                ButtonSegment(
                  value: TipoActividad.ejercicio,
                  icon: Icon(Icons.directions_walk),
                  label: Text('Moverse'),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombre,
              decoration: InputDecoration(
                labelText: 'Qué hacer (ej. Caminar 15 min)',
                border: const OutlineInputBorder(),
                errorText: _intento && _nombre.text.trim().isEmpty
                    ? 'Escribe la rutina'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _elegirHora,
              icon: const Icon(Icons.access_time),
              label: Text('Hora: ${_hora.format(context)}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Días',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(_nombresDias[i].substring(0, 2)),
                    tooltip: _nombresDias[i],
                    selected: _dias.contains(i),
                    onSelected: (si) =>
                        setState(() => si ? _dias.add(i) : _dias.remove(i)),
                  ),
              ],
            ),
            if (_intento && _dias.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Elige al menos un día',
                  style: TextStyle(color: ColoresNana.alerta),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
            if (widget.onEliminar != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  widget.onEliminar!();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar rutina'),
                style: TextButton.styleFrom(
                  foregroundColor: ColoresNana.alerta,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
