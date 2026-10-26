import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../data/repositorio.dart';
import '../widgets/aviso.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// Crear cuenta o iniciar sesión del cuidador, según [crear].
class CuentaCuidador extends StatefulWidget {
  final bool crear;
  const CuentaCuidador({super.key, required this.crear});

  @override
  State<CuentaCuidador> createState() => _CuentaCuidadorState();
}

class _CuentaCuidadorState extends State<CuentaCuidador> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _intento = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _apellidos, _telefono, _correo, _contrasena]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _errorNombre =>
      _nombre.text.trim().isEmpty ? 'Escribe tu nombre' : null;
  String? get _errorTelefono =>
      RegExp(r'^\d{10}$').hasMatch(_telefono.text.replaceAll(' ', ''))
      ? null
      : 'Escribe los 10 números de tu celular';
  String? get _errorCorreo => _correoValido.hasMatch(_correo.text.trim())
      ? null
      : 'Revisa tu correo, por ejemplo ana@gmail.com';
  String? get _errorContrasena => _contrasena.text.length < 6
      ? 'Necesita al menos 6 letras o números'
      : null;

  bool get _valido =>
      _errorCorreo == null &&
      _errorContrasena == null &&
      (!widget.crear || (_errorNombre == null && _errorTelefono == null));

  Future<void> _enviar() async {
    setState(() => _intento = true);
    if (!_valido) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final repo = Servicios.repo;
      if (widget.crear) {
        await repo.crearCuentaCuidador(
          nombre: _nombre.text.trim(),
          apellidos: _apellidos.text.trim(),
          telefono: _telefono.text.replaceAll(' ', ''),
          correo: _correo.text.trim(),
          contrasena: _contrasena.text,
        );
      } else {
        await repo.iniciarSesion(_correo.text.trim(), _contrasena.text);
      }
      final destino = await destinoInicial();
      if (mounted) entrarA(context, destino);
    } on ErrorNana catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _olvide() async {
    if (_errorCorreo != null) {
      setState(() {
        _intento = true;
        _error = 'Escribe tu correo arriba y vuelve a tocar "Olvidé mi contraseña".';
      });
      return;
    }
    try {
      await Servicios.repo.restablecerContrasena(_correo.text.trim());
      if (mounted) {
        mostrarAviso(context, 'Te mandamos un correo para cambiarla');
      }
    } on ErrorNana catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crear = widget.crear;
    String? si(String? e) => _intento ? e : null;
    void cambio(String _) => setState(() {});

    return PantallaPaso(
      barra: crear ? 'Crear cuenta' : 'Iniciar sesión',
      titulo: crear ? 'Tus datos' : 'Qué gusto verte',
      subtitulo: crear
          ? 'Con ellos te avisamos si tu familiar necesita algo.'
          : null,
      children: [
        if (_error != null) MensajeError(_error!),
        if (crear) ...[
          CampoNana(
            controller: _nombre,
            etiqueta: 'Nombre',
            error: si(_errorNombre),
            autollenado: const [AutofillHints.givenName],
            onChanged: cambio,
          ),
          CampoNana(
            controller: _apellidos,
            etiqueta: 'Apellidos',
            autollenado: const [AutofillHints.familyName],
          ),
          CampoNana(
            controller: _telefono,
            etiqueta: 'Celular (10 números)',
            teclado: TextInputType.phone,
            error: si(_errorTelefono),
            autollenado: const [AutofillHints.telephoneNumberNational],
            onChanged: cambio,
          ),
        ],
        CampoNana(
          controller: _correo,
          etiqueta: 'Correo',
          teclado: TextInputType.emailAddress,
          error: si(_errorCorreo),
          autollenado: const [AutofillHints.email],
          onChanged: cambio,
        ),
        CampoNana(
          controller: _contrasena,
          etiqueta: 'Contraseña',
          teclado: TextInputType.visiblePassword,
          oculto: true,
          error: si(_errorContrasena),
          autollenado: [
            crear ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onChanged: cambio,
        ),
        const SizedBox(height: 8),
        BotonPrincipal(
          texto: crear ? 'Crear mi cuenta' : 'Entrar',
          ocupado: _ocupado,
          onPressed: _enviar,
        ),
        if (!crear) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _olvide,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              textStyle: const TextStyle(fontSize: 20),
            ),
            child: const Text('Olvidé mi contraseña'),
          ),
        ],
      ],
    );
  }
}
