import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'codigo_vinculacion.dart';
import 'formulario_salud.dart';
import 'panel_cuidador.dart';

// Después de crear su cuenta, el cuidador da de alta a quien va a cuidar.
class AltaAdulto extends StatefulWidget {
  const AltaAdulto({super.key});

  static const parentescos = [
    'mamá',
    'papá',
    'abuela',
    'abuelo',
    'tía',
    'tío',
    'otro',
  ];

  @override
  State<AltaAdulto> createState() => _AltaAdultoState();
}

class _AltaAdultoState extends State<AltaAdulto> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  String? _parentesco;
  int _paso = 1; // 1 quién es, 2 ¿tiene celular?
  bool _intento = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    super.dispose();
  }

  String get _quien => _nombre.text.trim();
  String get _numero => _telefono.text.replaceAll(' ', '');
  bool get _telefonoMal =>
      _numero.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(_numero);

  void _siguiente() {
    setState(() => _intento = true);
    if (_quien.isEmpty || _parentesco == null || _telefonoMal) return;
    setState(() => _paso = 2);
  }

  Future<void> _darDeAlta({required bool tieneCelular}) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final repo = Servicios.repo;
      final folio = await repo.altaAdulto(
        nombre: _quien,
        apellidos: _apellidos.text.trim(),
        parentesco: _parentesco!,
        tieneCelular: tieneCelular,
        telefono: _numero.isEmpty ? null : _numero,
      );
      final codigo = tieneCelular ? await repo.generarCodigo(folio) : null;
      if (!mounted) return;
      final nombre = _quien;
      // Primero su salud (opcional) y después el código o el aviso.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FormularioSalud(
            folio: folio,
            nombre: nombre,
            alTerminar: (ctx) => Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(
                builder: (_) => codigo == null
                    ? SinCelular(nombre: nombre)
                    : PantallaCodigo(codigo: codigo, nombreAdulto: nombre),
              ),
            ),
          ),
        ),
      );
    } on ErrorNana catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_paso) {
      1 => _pasoQuien(),
      _ => _pasoCelular(),
    };
  }

  Widget _pasoQuien() {
    final faltaNombre = _intento && _quien.isEmpty;
    final faltaParentesco = _intento && _parentesco == null;
    return PantallaPaso(
      barra: 'Paso 1 de 2',
      titulo: '¿A quién vas a cuidar?',
      children: [
        CampoNana(
          controller: _nombre,
          etiqueta: 'Nombre',
          error: faltaNombre ? 'Escribe su nombre' : null,
          onChanged: (_) => setState(() {}),
        ),
        CampoNana(controller: _apellidos, etiqueta: 'Apellidos'),
        CampoNana(
          controller: _telefono,
          etiqueta: 'Su teléfono (opcional)',
          teclado: TextInputType.phone,
          error: _intento && _telefonoMal ? 'Escribe los 10 números' : null,
          onChanged: (_) => setState(() {}),
        ),
        const Text(
          '¿Qué es tuyo?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in AltaAdulto.parentescos)
              ChoiceChip(
                label: Text(p, style: const TextStyle(fontSize: 20)),
                selected: _parentesco == p,
                showCheckmark: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                selectedColor: ColoresNana.moradoClaro,
                onSelected: (_) => setState(() => _parentesco = p),
              ),
          ],
        ),
        if (faltaParentesco) ...[
          const SizedBox(height: 12),
          const MensajeError('Elige qué es tuyo'),
        ],
        const SizedBox(height: 28),
        BotonPrincipal(texto: 'Siguiente', onPressed: _siguiente),
      ],
    );
  }

  Widget _pasoCelular() {
    return PantallaPaso(
      barra: 'Paso 2 de 2',
      titulo: '¿$_quien tiene celular propio?',
      subtitulo:
          'Si tiene, te damos un código para que use NANA en su propio celular.',
      children: [
        if (_error != null) MensajeError(_error!),
        BotonPrincipal(
          texto: 'Sí, tiene celular',
          ocupado: _ocupado,
          onPressed: () => _darDeAlta(tieneCelular: true),
        ),
        const SizedBox(height: 16),
        BotonSecundario(
          texto: 'No tiene',
          onPressed: _ocupado ? null : () => _darDeAlta(tieneCelular: false),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _ocupado ? null : () => setState(() => _paso = 1),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          child: const Text('Regresar'),
        ),
      ],
    );
  }
}

class SinCelular extends StatelessWidget {
  final String nombre;
  const SinCelular({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      titulo: 'Tú llevarás el día de $nombre',
      subtitulo:
          'Desde tu celular anotas sus medicinas y cómo va. '
          'Si después tiene celular, genera su código en Mi cuenta.',
      children: [
        BotonPrincipal(
          texto: 'Ir a mi panel',
          onPressed: () => entrarA(context, const PanelCuidador()),
        ),
      ],
    );
  }
}
