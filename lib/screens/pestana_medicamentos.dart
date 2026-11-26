import 'leer_receta.dart';
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

// «¿Cada cuánto?»: (horas, texto). 24 = una vez al día.
const frecuencias = [
  (24, 'Una vez al día'),
  (12, 'Cada 12 horas'),
  (8, 'Cada 8 horas'),
  (6, 'Cada 6 horas'),
];

// «¿Por cuántos días?»: null = siempre (no se acaba).
const duraciones = <int?>[null, 3, 5, 7, 10, 14, 30];

const unidadesDosis = [
  'mg',
  'mcg',
  'g',
  'ml',
  'UI',
  'gotas',
  'tabletas',
  'cápsulas',
];

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
  Future<void> _leerReceta(BuildContext context) async {
    final tomas = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => LeerReceta(folio: widget.folio)),
    );
    if (tomas == null || tomas == 0 || !context.mounted) return;
    mostrarAviso(
      context,
      tomas == 1 ? 'NANA agregó 1 toma' : 'NANA agregó $tomas tomas',
    );
  }

  late final _meds = Servicios.repo.medicamentos(widget.folio);
  String get folio => widget.folio;

  void _abrirFormulario(BuildContext context, [GrupoMedicina? editar]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioMedicamento(
        existentes: editar?.tomas ?? const [],
        onGuardar: (m) => Servicios.repo.guardarMedicamento(folio, m),
        onBorrar: (id) => Servicios.repo.borrarMedicamento(folio, id),
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
    final grupos = agruparMedicinas(lista);
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
              for (final g in grupos) ...[
                _TarjetaMedicina(
                  grupo: g,
                  onEditar: widget.puedeEditar
                      ? () => _abrirFormulario(context, g)
                      : null,
                  estados: [
                    for (final m in g.tomas) _estadoDeHoy(m, hoy, faltan),
                  ],
                  onBorrar: !widget.puedeEditar
                      ? null
                      : () {
                          // Borra todas sus tomas; «Deshacer» las regresa todas.
                          for (final m in g.tomas) {
                            Servicios.repo.borrarMedicamento(folio, m.id!);
                          }
                          mostrarAviso(
                            context,
                            'Borré ${g.nombre}',
                            onDeshacer: () {
                              for (final m in g.tomas) {
                                Servicios.repo.guardarMedicamento(folio, m);
                              }
                            },
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
        if (widget.puedeEditar && Servicios.ocr.disponible)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: () => _leerReceta(context),
                icon: const Icon(Icons.document_scanner, size: 28),
                label: const Text('Leer una receta con la cámara'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresNana.morado,
                  side: const BorderSide(color: ColoresNana.morado, width: 2),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
    final ahora = Servicios.reloj();
    if (!m.empezo(ahora)) {
      final manana = DateTime(ahora.year, ahora.month, ahora.day + 1);
      final inicio = m.desde!;
      final esManana =
          inicio.year == manana.year &&
          inicio.month == manana.month &&
          inicio.day == manana.day;
      return (
        esManana ? 'Desde mañana' : 'Desde el ${diaCorto(inicio)}',
        ColoresNana.tintaSuave,
      );
    }
    if (faltan.contains(m)) return ('Falta', ColoresNana.alerta);
    return ('Más tarde', ColoresNana.tintaSuave);
  }
}

// Una medicina con todas sus tomas del día: nombre, dosis, «Cada 8 horas»,
// hasta cuándo, y un renglón por toma con su hora y cómo va hoy.
class _TarjetaMedicina extends StatelessWidget {
  final GrupoMedicina grupo;
  final List<(String, Color)> estados; // uno por toma, en el mismo orden
  final VoidCallback? onBorrar;
  final VoidCallback? onEditar; // null para el familiar (solo ve)

  const _TarjetaMedicina({
    required this.grupo,
    required this.estados,
    required this.onBorrar,
    this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final g = grupo;
    final hasta = g.hasta;
    final tarjeta = SuperficieCuidador(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.nombre,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${g.dosis} · ${g.frecuencia}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: ColoresNana.tintaSuave,
                  ),
                ),
                if (hasta != null)
                  Text(
                    'Hasta el ${diaCorto(hasta)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColoresNana.morado,
                    ),
                  ),
                const SizedBox(height: 8),
                for (final (i, m) in g.tomas.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          horaCorta(m.hora),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ColoresNana.morado,
                          ),
                        ),
                        _Estado(estados[i]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              if (onEditar != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar ${g.nombre}',
                  color: ColoresNana.morado,
                  constraints: const BoxConstraints(
                    minWidth: 64,
                    minHeight: 64,
                  ),
                  onPressed: onEditar,
                ),
              if (onBorrar != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Borrar ${g.nombre}',
                  color: ColoresNana.tintaSuave,
                  constraints: const BoxConstraints(
                    minWidth: 64,
                    minHeight: 64,
                  ),
                  onPressed: onBorrar,
                ),
            ],
          ),
        ],
      ),
    );
    // Tocar cualquier parte de la tarjeta también abre «Editar medicina».
    return onEditar == null
        ? tarjeta
        : InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onEditar,
            child: tarjeta,
          );
  }
}

class _Estado extends StatelessWidget {
  final (String, Color) estado;
  const _Estado(this.estado);

  @override
  Widget build(BuildContext context) {
    final (texto, color) = estado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}

class FormularioMedicamento extends StatefulWidget {
  final ValueChanged<Medicamento> onGuardar;
  // Para editar: las tomas que ya existen (la tarjeta de una medicina). Al
  // guardar se reusan sus ids en orden (no se pierde lo ya marcado hoy) y las
  // que sobran se borran con [onBorrar].
  final List<Medicamento> existentes;
  final ValueChanged<String>? onBorrar;
  const FormularioMedicamento({
    super.key,
    required this.onGuardar,
    this.existentes = const [],
    this.onBorrar,
  });

  @override
  State<FormularioMedicamento> createState() => _FormularioMedicamentoState();
}

class _FormularioMedicamentoState extends State<FormularioMedicamento> {
  final _nombre = TextEditingController();
  final _dosis = TextEditingController();
  String _unidad = unidadesDosis.first;
  // Empieza en la hora de ahora (redondeada a los siguientes 5 min), así ya
  // trae am o pm correcto; antes siempre empezaba en 8:00 am.
  TimeOfDay _hora = horaSugerida(Servicios.reloj());
  // Cada cuántas horas (24 = una vez al día). Las recetas dicen «cada 8 h».
  int _cada = 24;
  // Por cuántos días (null = siempre). «Otro» escribe el número.
  int? _dias;
  bool _otroDias = false;
  final _diasOtro = TextEditingController();
  int _ventana = 30;
  bool _intento = false;
  // Al editar una medicina con horas disparejas («3 veces al día» a deshoras).
  bool _horasDisparejas = false;

  bool get _editando => widget.existentes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _llenarCon(agruparMedicinas(widget.existentes).first);
    }
  }

  // Llena el formulario con lo que ya tiene la medicina.
  void _llenarCon(GrupoMedicina g) {
    _nombre.text = g.nombre;
    final partes = g.dosis.trim().split(' ');
    if (partes.length > 1 && unidadesDosis.contains(partes.last)) {
      _unidad = partes.last;
      _dosis.text = partes.sublist(0, partes.length - 1).join(' ');
    } else {
      _dosis.text = g.dosis.trim();
    }
    _hora = g.tomas.first.hora;
    final n = g.tomas.length;
    final cada = 24 ~/ n;
    if (n > 1 &&
        g.frecuencia == 'Cada $cada horas' &&
        frecuencias.any((f) => f.$1 == cada)) {
      _cada = cada;
    } else {
      _cada = 24;
      _horasDisparejas = n > 1;
    }
    final fin = g.hasta;
    if (fin != null) {
      final hoy = Servicios.reloj();
      final faltan =
          DateTime(
            fin.year,
            fin.month,
            fin.day,
          ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays +
          1;
      _otroDias = true;
      _diasOtro.text = '${faltan.clamp(1, 365)}';
    }
    final v = g.tomas.first.ventanaMin;
    _ventana = [15, 30, 60].contains(v) ? v : 30;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _dosis.dispose();
    _diasOtro.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: _cada < 24 ? 'Primera toma del día' : 'Hora de la medicina',
      // Siempre con AM/PM: con 24 h no se sabe si «8:00» es mañana o noche.
      builder: (context, hijo) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: hijo!,
      ),
    );
    if (h != null) setState(() => _hora = h);
  }

  List<TimeOfDay> get _tomas => horasPorFrecuencia(_hora, _cada);

  // Con «Otro»: número de 1 a 365, o null si todavía no es válido.
  int? get _diasElegidos {
    if (!_otroDias) return _dias;
    final n = int.tryParse(_diasOtro.text.trim());
    return n != null && n >= 1 && n <= 365 ? n : null;
  }

  DateTime? get _hasta {
    final d = _diasElegidos;
    return d == null ? null : Medicamento.ultimoDia(Servicios.reloj(), d);
  }

  bool get _diasMal => _otroDias && _diasElegidos == null;

  void _guardar() {
    setState(() => _intento = true);
    if (_nombre.text.trim().isEmpty ||
        errorDosis(_dosis.text) != null ||
        _diasMal) {
      return;
    }
    // Una medicina por toma: cada una tiene su propia alarma. Al editar se
    // reusan los ids en orden y las que sobran se borran.
    final viejas = [...widget.existentes]
      ..sort(
        (a, b) => (a.hora.hour * 60 + a.hora.minute).compareTo(
          b.hora.hour * 60 + b.hora.minute,
        ),
      );
    final tomas = [..._tomas]
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
    for (final (i, hora) in tomas.indexed) {
      final vieja = i < viejas.length ? viejas[i] : null;
      widget.onGuardar(
        Medicamento(
          id: vieja?.id,
          nombre: _nombre.text.trim(),
          dosis: '${_dosis.text.trim()} $_unidad',
          hora: hora,
          ventanaMin: _ventana,
          hasta: _hasta,
          // La que ya pasó hoy empieza mañana (alta a las 8:45 pm «cada 12 h»:
          // la de 8:45 am no cuenta hoy). Si al editar conserva su hora,
          // conserva también desde cuándo cuenta.
          desde: vieja != null && vieja.hora == hora
              ? vieja.desde
              : Medicamento.primerDia(hora, Servicios.reloj()),
        ),
      );
    }
    for (final vieja in viejas.skip(tomas.length)) {
      if (vieja.id != null) widget.onBorrar?.call(vieja.id!);
    }
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
              _editando ? 'Editar medicina' : 'Nuevo medicamento',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (_horasDisparejas)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Sus horas no van parejas. Elige «¿Cada cuánto?» y la primera '
                  'toma; al guardar quedará así.',
                  style: TextStyle(fontSize: 15, color: ColoresNana.alerta),
                ),
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
                    // Con letra grande «tabletas» no cabía: se recorta con «…».
                    isExpanded: true,
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
            const SizedBox(height: 16),
            const Text(
              '¿Cada cuánto?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (horas, nombre) in frecuencias)
                  ChoiceChip(
                    label: Text(nombre, style: const TextStyle(fontSize: 16)),
                    selected: _cada == horas,
                    onSelected: (_) => setState(() => _cada = horas),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _elegirHora,
              icon: const Icon(Icons.access_time),
              label: Text(
                _cada < 24
                    ? 'Primera toma: ${horaCorta(_hora)}'
                    : 'Hora: ${horaCorta(_hora)}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 8),
            // am / pm con un toque (el reloj del sistema lo esconde). Va a lo
            // ancho para que quepa con la letra al máximo.
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('am')),
                  ButtonSegment(value: true, label: Text('pm')),
                ],
                selected: {_hora.hour >= 12},
                onSelectionChanged: (s) =>
                    setState(() => _hora = conMitad(_hora, pm: s.first)),
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (_cada < 24) ...[
              const SizedBox(height: 8),
              Text(
                'Se toma a las: ${_tomas.map(horaCorta).join(' · ')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColoresNana.morado,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '¿Por cuántos días?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in duraciones)
                  ChoiceChip(
                    label: Text(
                      d == null ? 'Siempre' : '$d días',
                      style: const TextStyle(fontSize: 16),
                    ),
                    selected: !_otroDias && _dias == d,
                    onSelected: (_) => setState(() {
                      _otroDias = false;
                      _dias = d;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Otro', style: TextStyle(fontSize: 16)),
                  selected: _otroDias,
                  onSelected: (_) => setState(() => _otroDias = true),
                ),
              ],
            ),
            if (_otroDias) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _diasOtro,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Número de días',
                  border: const OutlineInputBorder(),
                  errorText: _intento && _diasMal
                      ? 'Escribe de 1 a 365 días'
                      : null,
                ),
              ),
            ],
            if (_hasta case final fin?) ...[
              const SizedBox(height: 8),
              Text(
                'Último día: ${diaCorto(fin)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColoresNana.morado,
                ),
              ),
            ],
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
            ElevatedButton(
              onPressed: _guardar,
              child: Text(_editando ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
