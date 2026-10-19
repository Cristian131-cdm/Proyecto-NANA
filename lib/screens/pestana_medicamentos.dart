import 'package:flutter/material.dart';
import '../core/tema.dart';
import '../models/medicamento.dart';

class PestanaMedicamentos extends StatefulWidget {
  const PestanaMedicamentos({super.key});

  @override
  State<PestanaMedicamentos> createState() => _PestanaMedicamentosState();
}

class _PestanaMedicamentosState extends State<PestanaMedicamentos> {
  final List<Medicamento> _lista = [
    const Medicamento(
      nombre: 'Losartán',
      dosis: '50 mg',
      hora: TimeOfDay(hour: 8, minute: 0),
      ventanaMin: 30,
    ),
  ];

  void _abrirFormulario() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioMedicamento(
        onGuardar: (m) => setState(() => _lista.add(m)),
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
      body: _lista.isEmpty
          ? const Center(
              child: Text('Aún no hay medicamentos programados',
                  style: TextStyle(fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _lista.length,
              itemBuilder: (context, i) {
                final m = _lista[i];
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
                      onPressed: () => setState(() => _lista.removeAt(i)),
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
    if (_nombre.text.trim().isEmpty || _dosis.text.trim().isEmpty) return;
    widget.onGuardar(Medicamento(
      nombre: _nombre.text.trim(),
      dosis: _dosis.text.trim(),
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
            TextField(
              controller: _dosis,
              decoration: InputDecoration(
                labelText: 'Dosis (ej. 50 mg)',
                border: const OutlineInputBorder(),
                errorText: _intento && _dosis.text.trim().isEmpty
                    ? 'Escribe la dosis'
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