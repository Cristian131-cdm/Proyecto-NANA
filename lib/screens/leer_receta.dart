import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/lector.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/medicina_leida.dart';
import '../widgets/mascota_nana.dart';
import 'pestana_medicamentos.dart' show errorDosis, unidadesDosis;

enum _Paso { foto, leyendo, revisar, nada, sinAgente }

/// «Leer una receta»: foto → NANA la lee → «¿Está bien así?».
/// La foto se lee en el celular y se borra; solo el texto va al agente.
/// No se guarda nada hasta que la familia toca «Sí, guardar».
/// Regresa cuántas tomas se guardaron (o null si se canceló).
class LeerReceta extends StatefulWidget {
  final String folio;
  const LeerReceta({super.key, required this.folio});

  @override
  State<LeerReceta> createState() => _LeerRecetaState();
}

class _Fila {
  MedicinaLeida m;
  bool incluir = true;
  final TextEditingController nombre;
  final TextEditingController dosis;
  _Fila(this.m)
    : nombre = TextEditingController(text: m.nombre),
      dosis = TextEditingController(text: m.dosis);
}

class _LeerRecetaState extends State<LeerReceta> {
  var _paso = _Paso.foto;
  List<_Fila> _filas = [];
  bool _intento = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _empezar());
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.nombre.dispose();
      f.dosis.dispose();
    }
    super.dispose();
  }

  Future<void> _empezar() async {
    setState(() => _paso = _Paso.foto);
    final texto = await Servicios.ocr.fotoYTexto();
    if (!mounted) return;
    if (texto == null) return Navigator.pop(context);
    setState(() => _paso = _Paso.leyendo);
    final meds = texto.trim().isEmpty
        ? const <MedicinaLeida>[]
        : await Servicios.agente.leerReceta(texto);
    if (!mounted) return;
    if (meds == null) return setState(() => _paso = _Paso.sinAgente);
    if (meds.isEmpty) return setState(() => _paso = _Paso.nada);
    setState(() {
      _filas = [for (final m in meds) _Fila(m)];
      _paso = _Paso.revisar;
    });
    final n = meds.length;
    nanaDice(
      context,
      n == 1
          ? 'Leí una medicina. Revisa que esté bien.'
          : 'Leí $n medicinas. Revisa que estén bien.',
    );
  }

  Future<void> _agregarHora(_Fila f) async {
    final h = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (h == null || f.m.horas.contains(h)) return;
    setState(
      () => f.m = f.m.copyWith(
        horas: [...f.m.horas, h]
          ..sort((a, b) => a.hour * 60 + a.minute - b.hour * 60 - b.minute),
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _intento = true);
    final elegidas = _filas.where((f) => f.incluir).toList();
    final malas = elegidas.where(
      (f) =>
          f.nombre.text.trim().isEmpty ||
          errorDosis(f.dosis.text) != null ||
          f.m.horas.isEmpty,
    );
    if (elegidas.isEmpty || malas.isNotEmpty) return;
    setState(() => _guardando = true);
    var tomas = 0;
    for (final f in elegidas) {
      final m = f.m.copyWith(
        nombre: f.nombre.text.trim(),
        dosis: f.dosis.text.trim(),
      );
      for (final med in m.comoMedicamentos(desde: Servicios.reloj())) {
        await Servicios.repo.guardarMedicamento(widget.folio, med);
        tomas++;
      }
    }
    if (mounted) Navigator.pop(context, tomas);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _paso == _Paso.revisar ? '¿Está bien así?' : 'Leer una receta',
        ),
      ),
      body: SafeArea(
        child: switch (_paso) {
          _Paso.foto || _Paso.leyendo => _esperando(),
          _Paso.revisar => _revisar(),
          _Paso.nada => _aviso(
            'No encontré medicinas en la foto',
            'Toma la foto con buena luz, de frente y que se vea toda la receta.',
          ),
          _Paso.sinAgente => _aviso(
            'NANA no pudo leer la receta',
            'Revisa que el agente esté prendido (Más opciones → Servidor de '
                'NANA) o agrega las medicinas a mano.',
          ),
        },
      ),
    );
  }

  Widget _esperando() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MascotaNana(tamano: 140, estado: EstadoNana.pensando),
          const SizedBox(height: 20),
          Text(
            _paso == _Paso.foto
                ? 'Toma la foto de la receta'
                : 'NANA está leyendo tu receta…',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'La foto se lee en este celular y no se guarda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: ColoresNana.tintaSuave),
          ),
        ],
      ),
    ),
  );

  Widget _aviso(String titulo, String detalle) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const MascotaNana(tamano: 120),
      const SizedBox(height: 16),
      Text(
        titulo,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        detalle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18),
      ),
      const SizedBox(height: 24),
      _botonGrande('Tomar otra foto', Icons.photo_camera, _empezar),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(minimumSize: const Size(0, 56)),
        child: const Text('Agregar a mano', style: TextStyle(fontSize: 18)),
      ),
    ],
  );

  Widget _revisar() => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Text(
              'Esto leyó NANA. Corrige lo que haga falta; nada se guarda hasta '
              'que toques «Sí, guardar».',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            for (final f in _filas) _tarjeta(f),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          children: [
            if (_intento && !_filas.any((f) => f.incluir))
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Marca al menos una medicina.',
                  style: TextStyle(fontSize: 18, color: ColoresNana.alerta),
                ),
              ),
            _botonGrande(
              'Sí, guardar',
              Icons.check,
              _guardando ? null : _guardar,
            ),
            TextButton.icon(
              onPressed: _guardando ? null : _empezar,
              icon: const Icon(Icons.photo_camera),
              label: const Text(
                'Tomar la foto otra vez',
                style: TextStyle(fontSize: 18),
              ),
              style: TextButton.styleFrom(minimumSize: const Size(0, 56)),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _tarjeta(_Fila f) {
    final errorNombre = _intento && f.incluir && f.nombre.text.trim().isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: f.incluir ? ColoresNana.morado : const Color(0xFFD9D2EA),
          width: f.incluir ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: f.incluir,
              onChanged: (v) => setState(() => f.incluir = v ?? false),
              title: const Text(
                'Agregar esta medicina',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextField(
              controller: f.nombre,
              enabled: f.incluir,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                labelText: 'Medicina',
                errorText: errorNombre ? 'Escribe el nombre' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: f.dosis,
                    enabled: f.incluir,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Dosis',
                      errorText: _intento && f.incluir
                          ? errorDosis(f.dosis.text)
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: unidadesDosis.contains(f.m.unidad) ? f.m.unidad : null,
                  hint: Text(f.m.unidad, style: const TextStyle(fontSize: 20)),
                  style: const TextStyle(
                    fontSize: 20,
                    color: ColoresNana.tinta,
                  ),
                  items: [
                    for (final u in unidadesDosis)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: f.incluir
                      ? (u) => setState(
                          () => f.m = f.m.copyWith(unidad: u ?? f.m.unidad),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'A qué horas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final h in f.m.horas)
                  InputChip(
                    label: Text(
                      horaCorta(h),
                      style: const TextStyle(fontSize: 18),
                    ),
                    onDeleted: f.incluir
                        ? () => setState(
                            () => f.m = f.m.copyWith(
                              horas: [...f.m.horas]..remove(h),
                            ),
                          )
                        : null,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Hora', style: TextStyle(fontSize: 18)),
                  onPressed: f.incluir ? () => _agregarHora(f) : null,
                ),
              ],
            ),
            if (_intento && f.incluir && f.m.horas.isEmpty)
              const Text(
                'Agrega al menos una hora',
                style: TextStyle(fontSize: 16, color: ColoresNana.alerta),
              ),
            if (f.m.dias > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Por ${f.m.dias} días (según la receta)',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            for (final d in f.m.dudas)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: ColoresNana.alerta),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(d, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _botonGrande(String texto, IconData icono, VoidCallback? alTocar) =>
      SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton.icon(
          onPressed: alTocar,
          icon: Icon(icono, size: 28),
          label: Text(texto),
          style: FilledButton.styleFrom(
            backgroundColor: ColoresNana.morado,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
