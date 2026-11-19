import '../models/registro.dart';
import '../models/actividad.dart';
import '../core/semana.dart' show horaDe;
import '../core/dia.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/medicamento.dart';
import '../widgets/aviso.dart';
import '../widgets/con_encargado.dart';
import '../widgets/tarjeta_dato.dart';

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
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final texto = nuevo.text.replaceAll(',', '.');
    if (!RegExp(r'^\d{0,4}(\.\d{0,3})?$').hasMatch(texto)) return anterior;
    return nuevo.copyWith(text: texto);
  }
}

// Las medicinas se guardan en Firestore y le aparecen al adulto en su día.
class PestanaMedicamentos extends StatefulWidget {
  final String folio;
  // false para el familiar invitado: ve las medicinas, no las cambia.
  final bool puedeEditar;
  // uid del encargado principal, para decirle al familiar quién las cambia.
  final String? creadoPor;
  const PestanaMedicamentos({
    super.key,
    required this.folio,
    this.puedeEditar = true,
    this.creadoPor,
  });

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

  late final _hoy = Servicios.repo.registrosDeHoy(widget.folio);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Registro>>(
        stream: _hoy,
        builder: (context, hoy) =>
            _lista(context, meds.data ?? const [], hoy.data ?? const []),
      ),
    );
  }

  Widget _lista(
    BuildContext context,
    List<Medicamento> lista,
    List<Registro> hoy,
  ) {
    final ahora = Servicios.reloj();
    final faltan = sinConfirmar(meds: lista, hoy: hoy, ahora: ahora);
    int minutos(Medicamento m) => m.hora.hour * 60 + m.hora.minute;
    final ordenada = [...lista]
      ..sort((a, b) => minutos(a).compareTo(minutos(b)));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              const Text(
                'Medicinas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ColoresNana.morado,
                ),
              ),
              const SizedBox(height: 12),
              if (lista.isEmpty)
                const TarjetaDato(
                  icono: Icons.medication_outlined,
                  titulo: 'Aún no hay medicamentos programados',
                ),
              for (final m in ordenada) ...[
                _TarjetaMedicina(
                  medicina: m,
                  estado: _estadoDeHoy(m, hoy, faltan),
                  onBorrar: !widget.puedeEditar
                      ? null
                      : () {
                          Servicios.repo.borrarMedicamento(folio, m.id!);
                          mostrarAviso(
                            context,
                            'Borré ${m.nombre}',
                            onDeshacer: () =>
                                Servicios.repo.guardarMedicamento(folio, m),
                          );
                        },
                ),
                const SizedBox(height: 10),
              ],
              if (!widget.puedeEditar) ...[
                const SizedBox(height: 6),
                ConEncargado(
                  folio: folio,
                  creadoPor: widget.creadoPor,
                  builder: (encargado) =>
                      AvisoCandado('Las agrega y cambia $encargado.'),
                ),
              ],
            ],
          ),
        ),
        if (widget.puedeEditar)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: () => _abrirFormulario(context),
                icon: const Icon(Icons.add, size: 28),
                label: const Text('Agregar medicina'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.morado,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Cómo va hoy cada medicina: ya la tomó (y a qué hora), falta (se pasó su
  // ventana) o le toca más tarde.
  (String, Color) _estadoDeHoy(
    Medicamento m,
    List<Registro> hoy,
    List<Medicamento> faltan,
  ) {
    final tomada = hoy
        .where(
          (r) => r.tipo == TipoActividad.medicina && r.idMedicamento == m.id,
        )
        .firstOrNull;
    if (tomada != null) return ('✓ ${horaDe(tomada.fecha)}', ColoresNana.ok);
    if (faltan.contains(m)) return ('Falta', ColoresNana.alerta);
    return ('Más tarde', ColoresNana.tintaSuave);
  }
}

class _TarjetaMedicina extends StatelessWidget {
  final Medicamento medicina;
  final (String, Color) estado;
  final VoidCallback? onBorrar;

  const _TarjetaMedicina({
    required this.medicina,
    required this.estado,
    required this.onBorrar,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicina;
    final (texto, color) = estado;
    final h = m.hora.hour;
    final parte = h < 12
        ? 'mañana'
        : h < 19
        ? 'tarde'
        : 'noche';
    return SuperficieCuidador(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Column(
              children: [
                FittedBox(
                  child: Text(
                    horaCorta(m.hora),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ColoresNana.morado,
                    ),
                  ),
                ),
                Text(
                  parte,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ColoresNana.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  m.dosis,
                  style: const TextStyle(
                    fontSize: 17,
                    color: ColoresNana.tintaSuave,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color == ColoresNana.ok
                        ? ColoresNana.okClaro
                        : color == ColoresNana.alerta
                        ? ColoresNana.alertaClaro
                        : ColoresNana.moradoClaro,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onBorrar != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Borrar ${m.nombre}',
              color: ColoresNana.tintaSuave,
              constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
              onPressed: onBorrar,
            ),
        ],
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
    widget.onGuardar(
      Medicamento(
        nombre: _nombre.text.trim(),
        dosis: '${_dosis.text.trim()} $_unidad',
        hora: _hora,
        ventanaMin: _ventana,
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
            const Text(
              'Nuevo medicamento',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ventana de confirmación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
