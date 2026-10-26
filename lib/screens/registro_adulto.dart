import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../data/repositorio.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'recomendar_huella.dart';

// Para el adulto que llega sin familia en NANA. Lo mínimo para tener cuenta.
class RegistroAdulto extends StatefulWidget {
  const RegistroAdulto({super.key});

  @override
  State<RegistroAdulto> createState() => _RegistroAdultoState();
}

class _RegistroAdultoState extends State<RegistroAdulto> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _intento = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _apellidos, _correo, _contrasena]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _errorNombre =>
      _nombre.text.trim().isEmpty ? 'Escribe tu nombre' : null;
  String? get _errorCorreo => _correo.text.contains('@') ? null : 'Revisa tu correo';
  String? get _errorContrasena =>
      _contrasena.text.length < 6 ? 'Necesita al menos 6 letras o números' : null;

  Future<void> _enviar() async {
    setState(() => _intento = true);
    if (_errorNombre != null || _errorCorreo != null || _errorContrasena != null) {
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await Servicios.repo.registrarAdulto(
        nombre: _nombre.text.trim(),
        apellidos: _apellidos.text.trim(),
        correo: _correo.text.trim(),
        contrasena: _contrasena.text,
      );
      if (mounted) await entrarRecomendandoHuella(context, pantallaDelAdulto());
    } on ErrorNana catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? si(String? e) => _intento ? e : null;
    void cambio(String _) => setState(() {});
    return PantallaPaso(
      barra: 'Registrarme',
      titulo: 'Cuéntame de ti',
      subtitulo: 'Después puedes invitar a tu familia.',
      children: [
        if (_error != null) MensajeError(_error!),
        CampoNana(
          controller: _nombre,
          etiqueta: 'Nombre',
          error: si(_errorNombre),
          onChanged: cambio,
        ),
        CampoNana(controller: _apellidos, etiqueta: 'Apellidos'),
        CampoNana(
          controller: _correo,
          etiqueta: 'Correo',
          teclado: TextInputType.emailAddress,
          error: si(_errorCorreo),
          onChanged: cambio,
        ),
        CampoNana(
          controller: _contrasena,
          etiqueta: 'Contraseña',
          teclado: TextInputType.visiblePassword,
          oculto: true,
          error: si(_errorContrasena),
          onChanged: cambio,
        ),
        const SizedBox(height: 8),
        BotonPrincipal(
          texto: 'Registrarme',
          ocupado: _ocupado,
          onPressed: _enviar,
        ),
      ],
    );
  }
}
