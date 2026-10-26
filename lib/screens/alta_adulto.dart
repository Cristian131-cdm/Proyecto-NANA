import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'codigo_vinculacion.dart';
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
  String? _parentesco;
  int _paso = 1; // 1 quién es, 2 ¿tiene celular?, 3 sin celular
  bool _intento = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    super.dispose();
  }

  String get _quien => _nombre.text.trim();

  void _siguiente() {
    setState(() => _intento = true);
    if (_quien.isEmpty || _parentesco == null) return;
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
      );
      if (!mounted) return;
      if (!tieneCelular) {
        setState(() => _paso = 3);
        return;
      }
      final codigo = await repo.generarCodigo(folio);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PantallaCodigo(codigo: codigo, nombreAdulto: _quien),
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
      2 => _pasoCelular(),
      _ => _pasoSinCelular(),
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

  Widget _pasoSinCelular() {
    return PantallaPaso(
      titulo: 'Tú llevarás el día de $_quien',
      subtitulo:
          'Desde tu celular anotas sus medicinas y cómo va. '
          'Si después tiene celular, genera su código en Ajustes.',
      children: [
        BotonPrincipal(
          texto: 'Ir a mi panel',
          onPressed: () => entrarA(context, const PanelCuidador()),
        ),
      ],
    );
  }
}
