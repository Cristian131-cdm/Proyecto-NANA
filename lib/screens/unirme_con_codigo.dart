import 'package:flutter/material.dart';

import '../core/codigo.dart';
import '../core/servicios.dart';
import '../data/repositorio.dart';
import '../widgets/campo_codigo.dart';
import '../widgets/formulario.dart';
import 'alta_adulto.dart';
import 'arranque.dart';
import 'panel_cuidador.dart';

// Un familiar que ya tiene cuenta escribe el código con el que lo invitaron
// y queda como cuidador de la misma persona.
class UnirmeConCodigo extends StatefulWidget {
  const UnirmeConCodigo({super.key});

  @override
  State<UnirmeConCodigo> createState() => _UnirmeConCodigoState();
}

class _UnirmeConCodigoState extends State<UnirmeConCodigo> {
  final _codigo = TextEditingController();
  String? _parentesco;
  bool _intento = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _unirme() async {
    final codigo = normalizarCodigo(_codigo.text);
    setState(() => _intento = true);
    if (codigo == null || _parentesco == null) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await Servicios.repo.unirmeComoFamiliar(codigo, _parentesco!);
      if (!mounted) return;
      entrarA(context, const PanelCuidador());
    } on ErrorNana catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listo = normalizarCodigo(_codigo.text) != null;
    return PantallaPaso(
      barra: 'Me invitaron',
      titulo: 'Escribe tu código de invitación',
      subtitulo: 'Son 6 números. Te los mandó quien ya cuida a tu familiar.',
      children: [
        if (_error != null) MensajeError(_error!),
        CampoCodigo(
          controller: _codigo,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 24),
        const Text(
          '¿Qué es tuyo la persona que vas a cuidar?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SelectorParentesco(
          valor: _parentesco,
          onCambio: (p) => setState(() => _parentesco = p),
        ),
        if (_intento && _parentesco == null) ...[
          const SizedBox(height: 12),
          const MensajeError('Elige qué es tuyo'),
        ],
        const SizedBox(height: 28),
        BotonPrincipal(
          texto: 'Unirme',
          ocupado: _ocupado,
          onPressed: listo ? _unirme : null,
        ),
      ],
    );
  }
}
