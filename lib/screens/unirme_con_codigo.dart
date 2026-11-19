import 'package:flutter/material.dart';

import '../core/codigo.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../models/adulto.dart';
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
  // La invitación ya revisada (y de qué código), para mostrar a quién va.
  Invitacion? _inv;
  String? _revisado;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  // Revisa el código en cuanto tiene los 6 números.
  Future<Invitacion?> _revisar() async {
    final codigo = normalizarCodigo(_codigo.text);
    if (codigo == null) return null;
    if (codigo == _revisado && _inv != null) return _inv;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final inv = await Servicios.repo.revisarInvitacion(codigo);
      if (!mounted || normalizarCodigo(_codigo.text) != codigo) return null;
      setState(() {
        _inv = inv;
        _revisado = codigo;
      });
      return inv;
    } on ErrorNana catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
      return null;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _continuar() async {
    final inv = await _revisar();
    if (inv == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuentaCuidador(crear: true, invitacion: inv),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listo = normalizarCodigo(_codigo.text) != null;
    final inv = _inv;
    return PantallaPaso(
      barra: 'Me invitaron',
      titulo: 'Escribe tu código de invitación',
      subtitulo: 'Son 6 números. Te los mandó quien ya cuida a tu familiar.',
      children: [
        if (_error != null) MensajeError(_error!),
        CampoCodigo(
          controller: _codigo,
          onChanged: (_) {
            setState(() {
              _error = null;
              _inv = null;
            });
            _revisar();
          },
          onSubmitted: _continuar,
        ),
        if (inv != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresNana.okClaro,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check, color: ColoresNana.ok, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vas a acompañar a ${inv.nombreAdulto}.'
                      '${inv.nombreInvita.isEmpty ? '' : ' Te invitó ${inv.nombreInvita}.'}',
                      style: const TextStyle(
                        fontSize: 19,
                        color: ColoresNana.tinta,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    if (codigo == null || !parentescoListo(_parentesco)) return;
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
        if (_intento && errorParentesco(_parentesco) != null) ...[
          const SizedBox(height: 12),
          MensajeError(errorParentesco(_parentesco)!),
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
