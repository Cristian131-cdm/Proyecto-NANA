import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../models/salud.dart';
import '../widgets/tarjeta_dato.dart';
import 'formulario_salud.dart';

// (médico, fecha, indicación)
typedef Receta = (String, String, String);

class PestanaHistorial extends StatefulWidget {
  final String adulto;
  final String folio;
  const PestanaHistorial({
    super.key,
    required this.adulto,
    required this.folio,
  });

  @override
  State<PestanaHistorial> createState() => _PestanaHistorialState();
}

class _PestanaHistorialState extends State<PestanaHistorial> {
  final List<Receta> _recetas = List.of(DatosEjemplo.recetas);
  late final _salud = Servicios.repo.salud(widget.folio);

  void _editarSalud(Salud actual) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FormularioSalud(
        folio: widget.folio,
        nombre: widget.adulto,
        inicial: actual,
      ),
    ),
  );

  void _agregar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioReceta(
        onGuardar: (r) => setState(() => _recetas.insert(0, r)),
      ),
    );
  }

  void _verDetalle(int i) {
    final r = _recetas[i];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.$3,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Indicó: ${r.$1}', style: const TextStyle(fontSize: 18)),
            Text('Fecha: ${r.$2}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                setState(() => _recetas.removeAt(i));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar receta'),
              style: TextButton.styleFrom(foregroundColor: ColoresNana.alerta),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adulto = widget.adulto;
    // El StreamBuilder va afuera de la lista para no volver a suscribirse
    // cada vez que la tarjeta sale y entra de la pantalla.
    return StreamBuilder<Salud>(
      stream: _salud,
      builder: (context, snap) => _lista(adulto, snap.data ?? Salud.vacia),
    );
  }

  Widget _lista(String adulto, Salud salud) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Lo que indicó el médico de $adulto',
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B6485)),
        ),
        const TituloSeccion('Recetas'),
        for (var i = 0; i < _recetas.length; i++)
          TarjetaDato(
            icono: Icons.description_outlined,
            titulo: '${_recetas[i].$1} · ${_recetas[i].$2}',
            subtitulo: _recetas[i].$3,
            onTap: () => _verDetalle(i),
          ),
        BotonSecundario(
          icono: Icons.note_add_outlined,
          texto: 'Agregar receta',
          onPressed: _agregar,
        ),
        const TituloSeccion('Datos de salud'),
        _DatosSalud(salud: salud, onEditar: () => _editarSalud(salud)),
        const TituloSeccion('Próximas citas'),
        for (final c in DatosEjemplo.citas)
          TarjetaDato(
            icono: Icons.event,
            titulo: c.$1,
            subtitulo: '${c.$2} · ${c.$3}',
            color: ColoresNana.azul,
          ),
        const SizedBox(height: 16),
        const Text(
          'NANA solo guarda lo que indicó un profesional de la salud.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B6485)),
        ),
      ],
    );
  }
}

// Padecimientos, alergias y lo demás que guardó la familia, con botón para editar.
class _DatosSalud extends StatelessWidget {
  final Salud salud;
  final VoidCallback onEditar;
  const _DatosSalud({required this.salud, required this.onEditar});

  Chip _chip(String texto, {bool alerta = false, IconData? icono}) => Chip(
    avatar: icono == null
        ? null
        : Icon(
            icono,
            color: alerta ? ColoresNana.alerta : ColoresNana.morado,
            size: 20,
          ),
    label: Text(
      texto,
      style: TextStyle(
        fontSize: 16,
        fontWeight: alerta ? FontWeight.bold : FontWeight.normal,
        color: alerta ? ColoresNana.alerta : ColoresNana.tinta,
      ),
    ),
    backgroundColor: alerta ? ColoresNana.alertaClaro : ColoresNana.moradoClaro,
    side: alerta
        ? const BorderSide(color: ColoresNana.alerta)
        : BorderSide.none,
    shape: const StadiumBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final medidas = [
      if (salud.pesoKg != null)
        '${salud.pesoKg!.toStringAsFixed(salud.pesoKg! % 1 == 0 ? 0 : 1)} kg',
      if (salud.estaturaCm != null) '${salud.estaturaCm} cm',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (salud.estaVacia)
          const Text(
            'Todavía no hay datos de salud. Puedes anotarlos o subir su '
            'expediente.',
            style: TextStyle(fontSize: 17),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in salud.padecimientos) _chip(p),
              for (final a in salud.alergias)
                _chip(
                  'Alergia: $a',
                  alerta: true,
                  icono: Icons.warning_amber_rounded,
                ),
              for (final m in salud.medicamentos)
                _chip(m, icono: Icons.medication_outlined),
              for (final d in salud.discapacidades)
                _chip(d, icono: Icons.accessibility_new),
            ],
          ),
          if (medidas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(medidas, style: const TextStyle(fontSize: 17)),
          ],
          if (salud.notas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(salud.notas, style: const TextStyle(fontSize: 17)),
          ],
          if (salud.origen == 'documento') ...[
            const SizedBox(height: 6),
            const Text(
              'Tomado de su expediente y revisado por la familia.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B6485)),
            ),
          ],
        ],
        const SizedBox(height: 12),
        BotonSecundario(
          icono: salud.estaVacia ? Icons.add : Icons.edit_outlined,
          texto: salud.estaVacia
              ? 'Agregar datos de salud'
              : 'Editar datos de salud',
          onPressed: onEditar,
        ),
      ],
    );
  }
}

class FormularioReceta extends StatefulWidget {
  final ValueChanged<Receta> onGuardar;
  const FormularioReceta({super.key, required this.onGuardar});

  @override
  State<FormularioReceta> createState() => _FormularioRecetaState();
}

class _FormularioRecetaState extends State<FormularioReceta> {
  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final _medico = TextEditingController();
  final _indicacion = TextEditingController();
  DateTime _fecha = DateTime.now();
  bool _intento = false;

  @override
  void dispose() {
    _medico.dispose();
    _indicacion.dispose();
    super.dispose();
  }

  String get _textoFecha => '${_fecha.day} ${_meses[_fecha.month - 1]}';

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (f != null) setState(() => _fecha = f);
  }

  void _guardar() {
    setState(() => _intento = true);
    if (_medico.text.trim().isEmpty || _indicacion.text.trim().isEmpty) return;
    widget.onGuardar((
      _medico.text.trim(),
      _textoFecha,
      _indicacion.text.trim(),
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
            const Text(
              'Nueva receta',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Registra solo lo indicado por un profesional de la salud.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _medico,
              decoration: InputDecoration(
                labelText: 'Médico (ej. Dr. Pérez)',
                border: const OutlineInputBorder(),
                errorText: _intento && _medico.text.trim().isEmpty
                    ? 'Escribe quién la indicó'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _indicacion,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Indicación (ej. Losartán 50 mg · 1 al día)',
                border: const OutlineInputBorder(),
                errorText: _intento && _indicacion.text.trim().isEmpty
                    ? 'Escribe lo que dice la receta'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.event),
              label: Text('Fecha: $_textoFecha'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
