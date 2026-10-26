import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/codigo.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'recomendar_huella.dart';

// El adulto escribe el código que le dio su familia. No hay contraseña.
class EntrarConCodigo extends StatefulWidget {
  const EntrarConCodigo({super.key});

  @override
  State<EntrarConCodigo> createState() => _EntrarConCodigoState();
}

class _EntrarConCodigoState extends State<EntrarConCodigo> {
  final _codigo = TextEditingController();
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final codigo = normalizarCodigo(_codigo.text);
    if (codigo == null) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final repo = Servicios.repo;
      final adulto = await repo.canjearCodigo(codigo);
      final familiar = await repo.nombreDeCuidador(adulto.folio);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _Conectado(nombre: adulto.nombre, familiar: familiar),
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
      barra: 'Entrar con un código',
      titulo: 'Escribe tu código',
      subtitulo: 'Son 6 números. Te lo dio tu familia.',
      children: [
        if (_error != null) MensajeError(_error!),
        TextField(
          controller: _codigo,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _entrar(),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            letterSpacing: 12,
            color: ColoresNana.morado,
          ),
          decoration: InputDecoration(
            hintText: '······',
            semanticCounterText: 'Código de 6 números',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 24),
        BotonPrincipal(
          texto: 'Entrar',
          ocupado: _ocupado,
          onPressed: listo ? _entrar : null,
        ),
      ],
    );
  }
}

class _Conectado extends StatelessWidget {
  final String nombre;
  final String familiar;

  const _Conectado({required this.nombre, required this.familiar});

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      titulo: 'Hola, $nombre',
      subtitulo: familiar.isEmpty
          ? 'Ya estás en NANA.'
          : 'Te conectaste con $familiar. Lo que anotes aquí le va a llegar.',
      children: [
        const Icon(Icons.favorite, color: ColoresNana.lila, size: 72),
        const SizedBox(height: 24),
        BotonPrincipal(
          texto: 'Continuar',
          onPressed: () =>
              entrarRecomendandoHuella(context, pantallaDelAdulto()),
        ),
      ],
    );
  }
}
