import 'package:flutter/material.dart';

import '../core/lector_expediente.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/salud.dart';
import '../widgets/aviso.dart';
import '../widgets/formulario.dart';

// Padecimientos, alergias y demás datos de salud del adulto. Se llena a mano
// o desde su expediente; en los dos casos la familia lo revisa antes de guardar.
class FormularioSalud extends StatefulWidget {
  final String folio;
  final String nombre;
  final Salud inicial;
  // Al venir del registro, a dónde sigue al guardar o con "Lo hago después".
  // Si es null, al guardar regresa a la pantalla anterior.
  final void Function(BuildContext context)? alTerminar;

  const FormularioSalud({
    super.key,
    required this.folio,
    required this.nombre,
    this.inicial = Salud.vacia,
    this.alTerminar,
  });

  @override
  State<FormularioSalud> createState() => _FormularioSaludState();
}

class _FormularioSaludState extends State<FormularioSalud> {
  late List<String> _padecimientos = List.of(widget.inicial.padecimientos);
  late List<String> _alergias = List.of(widget.inicial.alergias);
  late List<String> _medicamentos = List.of(widget.inicial.medicamentos);
  late final Set<String> _discapacidades = {...widget.inicial.discapacidades};
  late final _peso = TextEditingController(
    text: _numero(widget.inicial.pesoKg),
  );
  late final _estatura = TextEditingController(
    text: widget.inicial.estaturaCm?.toString() ?? '',
  );
  late final _notas = TextEditingController(text: widget.inicial.notas);

  String? _documento; // nombre del archivo que se leyó
  bool _leyendo = false;
  bool _guardando = false;
  bool _intento = false;
  String? _error;

  static String _numero(double? n) =>
      n == null ? '' : (n == n.roundToDouble() ? '${n.round()}' : '$n');

  @override
  void dispose() {
    _peso.dispose();
    _estatura.dispose();
    _notas.dispose();
    super.dispose();
  }

  double? get _pesoKg => double.tryParse(_peso.text.replaceAll(',', '.'));
  int? get _estaturaCm => int.tryParse(_estatura.text);

  String? get _errorPeso {
    if (_peso.text.isEmpty) return null;
    final p = _pesoKg;
    return p == null || p < 20 || p > 300 ? 'Escribe el peso en kilos' : null;
  }

  String? get _errorEstatura {
    if (_estatura.text.isEmpty) return null;
    final e = _estaturaCm;
    return e == null || e < 50 || e > 250
        ? 'Escribe la estatura en centímetros, por ejemplo 158'
        : null;
  }

  Future<void> _subir() async {
    final lector = Servicios.lector;
    setState(() => _error = null);
    try {
      final archivo = await lector.elegir();
      if (archivo == null || !mounted) return;
      setState(() => _leyendo = true);
      final leido = await lector.leer(archivo);
      if (!mounted) return;
      setState(() {
        _documento = archivo.nombre;
        // Se agrega a lo que ya estaba, sin repetir.
        _padecimientos = {..._padecimientos, ...leido.padecimientos}.toList();
        _alergias = {..._alergias, ...leido.alergias}.toList();
        _medicamentos = {..._medicamentos, ...leido.medicamentos}.toList();
        _discapacidades.addAll(leido.discapacidades);
        if (leido.pesoKg != null) _peso.text = _numero(leido.pesoKg);
        if (leido.estaturaCm != null) {
          _estatura.text = '${leido.estaturaCm}';
        }
      });
    } on ArchivoMuyGrande {
      setState(() => _error = 'El archivo pesa más de 10 MB. Prueba con otro.');
    } catch (_) {
      setState(
        () => _error = 'No se pudo leer el documento. Puedes llenarlo a mano.',
      );
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _intento = true);
    if (_errorPeso != null || _errorEstatura != null) return;
    setState(() => _guardando = true);
    await Servicios.repo.guardarSalud(
      widget.folio,
      Salud(
        padecimientos: _padecimientos,
        alergias: _alergias,
        medicamentos: _medicamentos,
        discapacidades: Salud.opcionesDiscapacidad
            .where(_discapacidades.contains)
            .toList(),
        pesoKg: _pesoKg,
        estaturaCm: _estaturaCm,
        notas: _notas.text.trim(),
        origen: _documento == null ? 'manual' : 'documento',
      ),
    );
    if (!mounted) return;
    mostrarAviso(context, 'Listo, guardé los datos de salud');
    _seguir();
  }

  void _seguir() {
    final siguiente = widget.alTerminar;
    if (siguiente == null) {
      Navigator.pop(context);
    } else {
      siguiente(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombre;
    final revisando = _documento != null;
    return PantallaPaso(
      barra: 'Salud de $nombre',
      titulo: revisando ? 'Revisa lo que encontré' : '¿Qué padece $nombre?',
      subtitulo: revisando
          ? null
          : 'Anota lo que indicó su médico o sube su expediente. '
                'Puedes cambiarlo cuando quieras.',
      children: [
        if (revisando)
          _Aviso(
            texto: Servicios.lector.esSimulado
                ? 'Demostración: NANA todavía no lee el documento de verdad; '
                      'estos datos son de ejemplo. Revísalos y corrige lo que '
                      'haga falta.'
                : 'Esto es lo que dice "$_documento". Revísalo y corrige lo '
                      'que haga falta antes de guardar.',
          )
        else
          _TarjetaSubir(leyendo: _leyendo, onTap: _leyendo ? null : _subir),
        if (_error != null) MensajeError(_error!),
        const SizedBox(height: 8),
        _ListaEditable(
          titulo: 'Padecimientos',
          ejemplo: 'Por ejemplo: Hipertensión',
          icono: Icons.monitor_heart_outlined,
          valores: _padecimientos,
          onCambio: (l) => setState(() => _padecimientos = l),
        ),
        _ListaEditable(
          titulo: 'Alergias',
          ejemplo: 'Por ejemplo: Penicilina',
          icono: Icons.warning_amber_rounded,
          esAlerta: true,
          valores: _alergias,
          onCambio: (l) => setState(() => _alergias = l),
        ),
        _ListaEditable(
          titulo: 'Medicinas que toma',
          ejemplo: 'Por ejemplo: Losartán 50 mg',
          icono: Icons.medication_outlined,
          nota: 'Los horarios se ponen en la pestaña Medicinas.',
          valores: _medicamentos,
          onCambio: (l) => setState(() => _medicamentos = l),
        ),
        const _Subtitulo(Icons.accessibility_new, '¿Necesita apoyo para…?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in Salud.opcionesDiscapacidad)
              FilterChip(
                label: Text(d, style: const TextStyle(fontSize: 18)),
                selected: _discapacidades.contains(d),
                selectedColor: ColoresNana.moradoClaro,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onSelected: (si) => setState(
                  () => si ? _discapacidades.add(d) : _discapacidades.remove(d),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CampoNana(
                controller: _peso,
                etiqueta: 'Peso (kg)',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                error: _intento ? _errorPeso : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CampoNana(
                controller: _estatura,
                etiqueta: 'Estatura (cm)',
                teclado: TextInputType.number,
                error: _intento ? _errorEstatura : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        CampoNana(
          controller: _notas,
          etiqueta: 'Notas (opcional)',
          teclado: TextInputType.text,
        ),
        const SizedBox(height: 8),
        BotonPrincipal(
          texto: revisando ? 'Sí, es correcto, guardar' : 'Guardar',
          ocupado: _guardando,
          onPressed: _leyendo ? null : _guardar,
        ),
        if (widget.alTerminar != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _guardando ? null : _seguir,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              textStyle: const TextStyle(fontSize: 20),
            ),
            child: const Text('Lo hago después'),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'NANA solo guarda lo que indicó un profesional de la salud. '
          'No da recomendaciones médicas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6B6485)),
        ),
      ],
    );
  }
}

class _TarjetaSubir extends StatelessWidget {
  final bool leyendo;
  final VoidCallback? onTap;
  const _TarjetaSubir({required this.leyendo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: ColoresNana.moradoClaro,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                leyendo
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(
                        Icons.upload_file,
                        size: 40,
                        color: ColoresNana.morado,
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leyendo
                            ? 'NANA está leyendo el documento…'
                            : 'Subir expediente (PDF o foto)',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ColoresNana.morado,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'NANA lo lee y tú lo revisas. El documento no se '
                        'guarda.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColoresNana.alertaClaro,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.fact_check_outlined, color: ColoresNana.alerta),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 18))),
          ],
        ),
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Subtitulo(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Icon(icono, color: ColoresNana.morado, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Lista de textos con chips: se agrega escribiendo y se quita con la ✕.
class _ListaEditable extends StatefulWidget {
  final String titulo;
  final String ejemplo;
  final IconData icono;
  final String? nota;
  final bool esAlerta;
  final List<String> valores;
  final ValueChanged<List<String>> onCambio;

  const _ListaEditable({
    required this.titulo,
    required this.ejemplo,
    required this.icono,
    this.nota,
    this.esAlerta = false,
    required this.valores,
    required this.onCambio,
  });

  @override
  State<_ListaEditable> createState() => _ListaEditableState();
}

class _ListaEditableState extends State<_ListaEditable> {
  final _nuevo = TextEditingController();

  @override
  void dispose() {
    _nuevo.dispose();
    super.dispose();
  }

  void _agregar() {
    final texto = _nuevo.text.trim();
    if (texto.isEmpty) return;
    final ya = widget.valores.any(
      (v) => v.toLowerCase() == texto.toLowerCase(),
    );
    if (!ya) widget.onCambio([...widget.valores, texto]);
    _nuevo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.esAlerta ? ColoresNana.alerta : ColoresNana.morado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Subtitulo(widget.icono, widget.titulo),
        if (widget.valores.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in widget.valores)
                InputChip(
                  label: Text(
                    v,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.esAlerta ? color : ColoresNana.tinta,
                    ),
                  ),
                  backgroundColor: widget.esAlerta
                      ? ColoresNana.alertaClaro
                      : ColoresNana.moradoClaro,
                  side: widget.esAlerta
                      ? const BorderSide(color: ColoresNana.alerta)
                      : BorderSide.none,
                  deleteIconColor: color,
                  deleteButtonTooltipMessage: 'Quitar $v',
                  onDeleted: () => widget.onCambio(
                    widget.valores.where((x) => x != v).toList(),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nuevo,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _agregar(),
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  hintText: widget.ejemplo,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _agregar,
              tooltip: 'Agregar a ${widget.titulo.toLowerCase()}',
              iconSize: 30,
              style: IconButton.styleFrom(
                backgroundColor: ColoresNana.morado,
                minimumSize: const Size(60, 60),
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (widget.nota != null) ...[
          const SizedBox(height: 6),
          Text(widget.nota!, style: const TextStyle(fontSize: 15)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
