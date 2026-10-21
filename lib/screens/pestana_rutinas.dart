import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../models/actividad.dart';
import '../widgets/tarjeta_dato.dart';

const _nombresDias = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
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

Set<int> _diasDeTexto(String texto) {
  if (texto == 'Todos los días') return {0, 1, 2, 3, 4, 5, 6};
  if (texto == 'Lunes a viernes') return {0, 1, 2, 3, 4};
  final dias = <int>{};
  for (var i = 0; i < _nombresDias.length; i++) {
    if (texto.toLowerCase().contains(_nombresDias[i].toLowerCase())) {
      dias.add(i);
    }
  }
  return dias;
}

// Lee horas como "7:30" o "2:00 pm" de los datos de ejemplo.
TimeOfDay _horaDeTexto(String texto) {
  final m = RegExp(r'(\d+):(\d+)\s*(am|pm)?', caseSensitive: false)
      .firstMatch(texto);
  if (m == null) return const TimeOfDay(hour: 8, minute: 0);
  var h = int.parse(m.group(1)!);
  final pm = m.group(3)?.toLowerCase() == 'pm';
  if (pm && h < 12) h += 12;
  return TimeOfDay(hour: h, minute: int.parse(m.group(2)!));
}

class PestanaRutinas extends StatefulWidget {
  const PestanaRutinas({super.key});

  @override
  State<PestanaRutinas> createState() => _PestanaRutinasState();
}

class _PestanaRutinasState extends State<PestanaRutinas> {
  final List<Actividad> _rutinas = List.of(DatosEjemplo.rutinas);

  void _abrirFormulario([int? indice]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioRutina(
        inicial: indice == null ? null : _rutinas[indice],
        onGuardar: (r) => setState(() {
          if (indice == null) {
            _rutinas.add(r);
          } else {
            _rutinas[indice] = r;
          }
        }),
        onEliminar: indice == null
            ? null
            : () => setState(() => _rutinas.removeAt(indice)),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          const Text(
            'NANA le recuerda estas cosas a lo largo del día.',
            style: TextStyle(fontSize: 16, color: Color(0xFF6B6485)),
          ),
          const TituloSeccion('Comidas'),
          ..._de(TipoActividad.comida),
          const TituloSeccion('Moverse'),
          ..._de(TipoActividad.ejercicio),
        ],
      ),
    );
  }

  List<Widget> _de(TipoActividad tipo) {
    return [
      for (var i = 0; i < _rutinas.length; i++)
        if (_rutinas[i].tipo == tipo)
          TarjetaDato(
            icono: tipo.icono,
            titulo: '${_rutinas[i].titulo} · ${_rutinas[i].hora}',
            subtitulo: _rutinas[i].detalle,
            color: tipo == TipoActividad.comida
                ? ColoresNana.ok
                : ColoresNana.azul,
            onTap: () => _abrirFormulario(i),
          ),
    ];
  }
}

class FormularioRutina extends StatefulWidget {
  final Actividad? inicial;
  final ValueChanged<Actividad> onGuardar;
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
  late TimeOfDay _hora = widget.inicial == null
      ? const TimeOfDay(hour: 8, minute: 0)
      : _horaDeTexto(widget.inicial!.hora);
  late final Set<int> _dias = widget.inicial == null
      ? {0, 1, 2, 3, 4, 5, 6}
      : _diasDeTexto(widget.inicial!.detalle);
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
    widget.onGuardar(Actividad(
      hora: _hora.format(context),
      titulo: _nombre.text.trim(),
      detalle: textoDias(_dias),
      tipo: _tipo,
      estado: EstadoActividad.pendiente,
    ));
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
            Text(widget.inicial == null ? 'Nueva rutina' : 'Editar rutina',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                    label: Text('Comida')),
                ButtonSegment(
                    value: TipoActividad.ejercicio,
                    icon: Icon(Icons.directions_walk),
                    label: Text('Moverse')),
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
                  minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: 16),
            const Text('Días',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                    onSelected: (si) => setState(
                        () => si ? _dias.add(i) : _dias.remove(i)),
                  ),
              ],
            ),
            if (_intento && _dias.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Elige al menos un día',
                    style: TextStyle(color: ColoresNana.alerta)),
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
                style:
                    TextButton.styleFrom(foregroundColor: ColoresNana.alerta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
