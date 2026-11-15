import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/fotos_locales.dart';
import '../core/permisos.dart';

import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/receta.dart';
import '../models/salud.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';
import 'formulario_salud.dart';

class PestanaHistorial extends StatefulWidget {
  final String adulto;
  final String folio;
  // false para el suplente: ve el expediente, no lo cambia.
  final bool puedeEditar;
  const PestanaHistorial({
    super.key,
    required this.adulto,
    required this.folio,
    this.puedeEditar = true,
  });

  @override
  State<PestanaHistorial> createState() => _PestanaHistorialState();
}

class _PestanaHistorialState extends State<PestanaHistorial> {
  late final _salud = Servicios.repo.salud(widget.folio);
  late final _recetas = Servicios.repo.recetas(widget.folio);
  late final _citas = Servicios.repo.citas(widget.folio);

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
        onGuardar: (r, foto) {
          // El id se decide aquí para poder ligar la foto, que no sube.
          final id = 'r${DateTime.now().microsecondsSinceEpoch}';
          Servicios.repo.guardarReceta(widget.folio, r.conId(id));
          if (foto != null) Servicios.fotos.guardar(id, foto);
          mostrarAviso(context, 'Receta guardada');
        },
      ),
    );
  }

  void _agregarCita() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioCita(
        onGuardar: (c) {
          Servicios.repo.guardarCita(widget.folio, c);
          mostrarAviso(context, 'Cita guardada');
        },
      ),
    );
  }

  void _verCita(Cita c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.especialidad,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_textoCita(context, c), style: const TextStyle(fontSize: 18)),
            if (c.lugar.isNotEmpty)
              Text('En: ${c.lugar}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            if (widget.puedeEditar)
              TextButton.icon(
                onPressed: () {
                  Servicios.repo.borrarCita(widget.folio, c.id!);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar cita'),
                style: TextButton.styleFrom(
                  foregroundColor: ColoresNana.alerta,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _verDetalle(Receta r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.indicacion,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text('Indicó: ${r.medico}', style: const TextStyle(fontSize: 18)),
              Text(
                'Fecha: ${fechaCorta(r.fecha)}',
                style: const TextStyle(fontSize: 18),
              ),
              FutureBuilder<Uint8List?>(
                future: Servicios.fotos.leer(r.id!),
                builder: (context, foto) => foto.data == null
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                foto.data!,
                                semanticLabel: 'Foto de la receta',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              avisoFotoLocal,
                              style: TextStyle(
                                fontSize: 15,
                                color: ColoresNana.tintaSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              if (widget.puedeEditar)
                TextButton.icon(
                  onPressed: () {
                    Servicios.repo.borrarReceta(widget.folio, r.id!);
                    Servicios.fotos.borrar(r.id!);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar receta'),
                  style: TextButton.styleFrom(
                    foregroundColor: ColoresNana.alerta,
                  ),
                ),
            ],
          ),
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
      builder: (context, salud) => StreamBuilder<List<Receta>>(
        stream: _recetas,
        builder: (context, recetas) => StreamBuilder<List<Cita>>(
          stream: _citas,
          builder: (context, citas) => _lista(
            adulto,
            salud.data ?? Salud.vacia,
            recetas.data ?? const [],
            citas.data ?? const [],
          ),
        ),
      ),
    );
  }

  Widget _lista(
    String adulto,
    Salud salud,
    List<Receta> recetas,
    List<Cita> citas,
  ) {
    final hoy = DateUtils.dateOnly(Servicios.reloj());
    final proximas = [
      for (final c in citas)
        if (!c.fecha.isBefore(hoy)) c,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        CabeceraCuidador(
          titulo: 'Su expediente',
          detalle: 'Lo que indicó el médico de $adulto',
          icono: Icons.folder_outlined,
        ),
        const TituloSeccion('Recetas'),
        if (recetas.isEmpty) const _Vacio('Todavía no hay recetas guardadas.'),
        for (final r in recetas)
          TarjetaDato(
            icono: Icons.description_outlined,
            titulo: '${r.medico} · ${fechaCorta(r.fecha)}',
            subtitulo: r.indicacion,
            onTap: () => _verDetalle(r),
          ),
        if (widget.puedeEditar)
          BotonSecundario(
            icono: Icons.note_add_outlined,
            texto: 'Agregar receta',
            onPressed: _agregar,
          ),
        const TituloSeccion('Próximas citas'),
        if (proximas.isEmpty) const _Vacio('No hay citas próximas.'),
        for (final c in proximas)
          TarjetaDato(
            icono: Icons.event,
            titulo: c.especialidad,
            subtitulo: [
              _textoCita(context, c),
              if (c.lugar.isNotEmpty) c.lugar,
            ].join(' · '),
            color: ColoresNana.azul,
            onTap: () => _verCita(c),
          ),
        if (widget.puedeEditar)
          BotonSecundario(
            icono: Icons.event_available,
            texto: 'Agregar cita',
            onPressed: _agregarCita,
          ),
        const TituloSeccion('Datos de salud'),
        SuperficieCuidador(
          child: _DatosSalud(
            salud: salud,
            onEditar: widget.puedeEditar
                ? () => _editarSalud(salud)
                : () => mostrarAviso(context, avisoSoloPrincipal),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'NANA solo guarda lo que indicó un profesional de la salud.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: ColoresNana.tintaSuave),
        ),
      ],
    );
  }
}

String _textoCita(BuildContext context, Cita c) =>
    '${fechaCorta(c.fecha)} · ${TimeOfDay.fromDateTime(c.fecha).format(context)}';

class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
    ),
  );
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
              style: TextStyle(fontSize: 14, color: ColoresNana.tintaSuave),
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

const avisoFotoLocal =
    'La foto se queda solo en este celular. No se sube y nadie más la ve.';

class FormularioReceta extends StatefulWidget {
  // La foto es opcional y nunca sale del celular.
  final void Function(Receta receta, Uint8List? foto) onGuardar;
  const FormularioReceta({super.key, required this.onGuardar});

  @override
  State<FormularioReceta> createState() => _FormularioRecetaState();
}

class _FormularioRecetaState extends State<FormularioReceta> {
  final _medico = TextEditingController();
  final _indicacion = TextEditingController();
  DateTime _fecha = DateTime.now();
  bool _intento = false;
  Uint8List? _foto;

  Future<void> _elegirFoto() async {
    try {
      final foto = await Servicios.fotos.elegir();
      if (foto != null && mounted) setState(() => _foto = foto);
    } on FotoMuyGrande {
      if (mounted) mostrarAviso(context, 'Esa foto pesa más de 10 MB');
    }
  }

  @override
  void dispose() {
    _medico.dispose();
    _indicacion.dispose();
    super.dispose();
  }

  String get _textoFecha => fechaCorta(_fecha);

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
    widget.onGuardar(
      Receta(
        medico: _medico.text.trim(),
        fecha: _fecha,
        indicacion: _indicacion.text.trim(),
      ),
      _foto,
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
            if (Servicios.fotos.disponible) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _elegirFoto,
                icon: Icon(
                  _foto == null ? Icons.add_a_photo_outlined : Icons.check,
                ),
                label: Text(
                  _foto == null ? 'Agregar foto (opcional)' : 'Foto agregada',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                avisoFotoLocal,
                style: TextStyle(fontSize: 13, color: ColoresNana.tintaSuave),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}

class FormularioCita extends StatefulWidget {
  final ValueChanged<Cita> onGuardar;
  const FormularioCita({super.key, required this.onGuardar});

  @override
  State<FormularioCita> createState() => _FormularioCitaState();
}

class _FormularioCitaState extends State<FormularioCita> {
  final _especialidad = TextEditingController();
  final _lugar = TextEditingController();
  late DateTime _dia = DateUtils.dateOnly(Servicios.reloj())
      .add(const Duration(days: 1));
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  bool _intento = false;

  @override
  void dispose() {
    _especialidad.dispose();
    _lugar.dispose();
    super.dispose();
  }

  Future<void> _elegirDia() async {
    final hoy = DateUtils.dateOnly(Servicios.reloj());
    final f = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 730)),
    );
    if (f != null) setState(() => _dia = f);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  void _guardar() {
    setState(() => _intento = true);
    if (_especialidad.text.trim().isEmpty) return;
    widget.onGuardar(
      Cita(
        especialidad: _especialidad.text.trim(),
        fecha: _dia.add(Duration(hours: _hora.hour, minutes: _hora.minute)),
        lugar: _lugar.text.trim(),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nueva cita',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _especialidad,
              decoration: InputDecoration(
                labelText: 'Con quién o para qué (ej. Cardiología)',
                border: const OutlineInputBorder(),
                errorText: _intento && _especialidad.text.trim().isEmpty
                    ? 'Escribe de qué es la cita'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lugar,
              decoration: const InputDecoration(
                labelText: 'Lugar (opcional, ej. Clínica 25)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _elegirDia,
              icon: const Icon(Icons.event),
              label: Text('Día: ${fechaCorta(_dia)}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _elegirHora,
              icon: const Icon(Icons.access_time),
              label: Text('Hora: ${_hora.format(context)}'),
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
