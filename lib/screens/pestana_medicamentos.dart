import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/medicamento.dart';

const unidadesDosis = ['mg', 'mcg', 'g', 'ml', 'UI', 'gotas', 'tabletas'];

// Reglas para escribir dosis sin que se lean mal: siempre un cero antes del
// punto (0.5, no .5) y nunca un cero al final (5, no 5.0, que se lee 50).
String? errorDosis(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return 'Escribe la dosis';
  if (t.startsWith('.')) return 'Pon un cero antes del punto: 0$t';
  if (t.endsWith('.')) return 'Termina el número o quita el punto';
  if (t.length > 1 && t.startsWith('0') && !t.startsWith('0.')) {
    return 'Quita el cero del inicio';
  }
  if (t.contains('.') && t.endsWith('0')) {
    final limpio = t.replaceFirst(RegExp(r'\.?0+$'), '');
    return 'Quita el cero final: escribe $limpio';
  }
  if (double.parse(t) == 0) return 'La dosis debe ser mayor que cero';
  return null;
}

// Solo deja escribir números con un punto decimal. La coma se cambia por
// punto porque muchos teclados en español la ponen.
class _FormatoDosis extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    final texto = nuevo.text.replaceAll(',', '.');
    if (!RegExp(r'^\d{0,4}(\.\d{0,3})?$').hasMatch(texto)) return anterior;
    return nuevo.copyWith(text: texto);
  }
}

// Las medicinas se guardan en Firestore y le aparecen al adulto en su día.
class PestanaMedicamentos extends StatefulWidget {
  final String folio;
  const PestanaMedicamentos({super.key, required this.folio});

  @override
  State<PestanaMedicamentos> createState() => _PestanaMedicamentosState();
}

class _PestanaMedicamentosState extends State<PestanaMedicamentos> {
  late final _meds = Servicios.repo.medicamentos(widget.folio);
  String get folio => widget.folio;

  void _abrirFormulario(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioMedicamento(
        onGuardar: (m) => Servicios.repo.guardarMedicamento(folio, m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, snap) => _lista(context, snap.data ?? const []),
    );
  }

  Widget _lista(BuildContext context, List<Medicamento> lista) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        backgroundColor: ColoresNana.morado,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar', style: TextStyle(fontSize: 18)),
      ),
      body: lista.isEmpty
          ? const Center(
              child: Text('Aún no hay medicamentos programados',
                  style: TextStyle(fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final m = lista[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: ColoresNana.moradoClaro,
                      child: Icon(Icons.medication, color: ColoresNana.morado),
                    ),
                    title: Text('${m.nombre} · ${m.dosis}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${m.hora.format(context)} · alerta si no confirma en ${m.ventanaMin} min'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Borrar ${m.nombre}',
                      onPressed: () =>
                          Servicios.repo.borrarMedicamento(folio, m.id!),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FormularioMedicamento extends StatefulWidget {
  final ValueChanged<Medicamento> onGuardar;
  const FormularioMedicamento({super.key, required this.onGuardar});

  @override
  State<FormularioMedicamento> createState() => _FormularioMedicamentoState();
}

class _FormularioMedicamentoState extends State<FormularioMedicamento> {
  final _nombre = TextEditingController();
  final _dosis = TextEditingController();
  String _unidad = unidadesDosis.first;
  TimeOfDay _hora = const TimeOfDay(hour: 8, minute: 0);
  int _ventana = 30;
  bool _intento = false;

  @override
  void dispose() {
    _nombre.dispose();
    _dosis.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  void _guardar() {
    setState(() => _intento = true);
    if (_nombre.text.trim().isEmpty || errorDosis(_dosis.text) != null) return;
    widget.onGuardar(Medicamento(
      nombre: _nombre.text.trim(),
      dosis: '${_dosis.text.trim()} $_unidad',
      hora: _hora,
      ventanaMin: _ventana,
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
            const Text('Nuevo medicamento',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Registra solo lo indicado por un profesional de la salud.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombre,
              decoration: InputDecoration(
                labelText: 'Medicamento',
                border: const OutlineInputBorder(),
                errorText: _intento && _nombre.text.trim().isEmpty
                    ? 'Escribe el nombre'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _dosis,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_FormatoDosis()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Dosis',
                      hintText: 'ej. 0.5 o 50',
                      helperText: 'Escribe 0.5, no .5 · 5, no 5.0',
                      helperMaxLines: 2,
                      errorMaxLines: 2,
                      border: const OutlineInputBorder(),
                      errorText: _intento ? errorDosis(_dosis.text) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unidad,
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final u in unidadesDosis)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (u) => setState(() => _unidad = u!),
                  ),
                ),
              ],
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
            const Text('Ventana de confirmación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 15, label: Text('15 min')),
                ButtonSegment(value: 30, label: Text('30 min')),
                ButtonSegment(value: 60, label: Text('60 min')),
              ],
              selected: {_ventana},
              onSelectionChanged: (s) => setState(() => _ventana = s.first),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}