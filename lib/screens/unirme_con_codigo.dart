import 'package:flutter/material.dart';

import '../core/codigo.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../widgets/campo_codigo.dart';
import '../widgets/formulario.dart';
import 'alta_adulto.dart';
import 'arranque.dart';
import 'bienvenida_familiar.dart';
import 'cuenta_cuidador.dart';

// Quien todavía no tiene cuenta escribe primero su código de invitación;
// si sirve, pasa al formulario que crea su cuenta y lo une.
class InvitadoConCodigo extends StatefulWidget {
  const InvitadoConCodigo({super.key});

  @override
  State<InvitadoConCodigo> createState() => _InvitadoConCodigoState();
}

class _InvitadoConCodigoState extends State<InvitadoConCodigo> {
  final _codigo = TextEditingController();
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final codigo = normalizarCodigo(_codigo.text);
    if (codigo == null) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final inv = await Servicios.repo.revisarInvitacion(codigo);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CuentaCuidador(crear: true, invitacion: inv),
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
    final listo = normalizarCodigo(_codigo.text) != null;
    return PantallaPaso(
      barra: 'Código de invitación',
      titulo: 'Escribe tu código de invitación',
      subtitulo: 'Son 6 números. Te los mandó quien ya cuida a tu familiar.',
      children: [
        if (_error != null) MensajeError(_error!),
        CampoCodigo(
          controller: _codigo,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: _continuar,
        ),
        const SizedBox(height: 24),
        BotonPrincipal(
          texto: 'Continuar',
          ocupado: _ocupado,
          onPressed: listo ? _continuar : null,
        ),
        const SizedBox(height: 20),
        const Text(
          'Después llenas tus datos para crear tu cuenta.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: ColoresNana.tintaSuave),
        ),
      ],
    );
  }
}

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
      final adulto = await Servicios.repo.unirmeComoFamiliar(
        codigo,
        _parentesco!,
      );
      if (!mounted) return;
      entrarA(context, BienvenidaFamiliar(adulto: adulto));
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
