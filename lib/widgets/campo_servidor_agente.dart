import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/servicios.dart';
import '../core/tema.dart';

/// «Servidor de NANA (pruebas)»: la IP de la laptop donde corre el agente y
/// la clave de la demo que muestra «Arrancar NANA» al prenderse. Va en «Más
/// opciones» porque solo se usa para probar y en la demo.
class CampoServidorAgente extends StatefulWidget {
  const CampoServidorAgente({super.key});

  @override
  State<CampoServidorAgente> createState() => _CampoServidorAgenteState();
}

class _CampoServidorAgenteState extends State<CampoServidorAgente> {
  late final _ip = TextEditingController(text: Ajustes.servidorAgente.value);
  late final _clave = TextEditingController(text: Ajustes.claveAgente.value);
  String? _estado;
  bool _bien = false;
  bool _probando = false;

  @override
  void dispose() {
    _ip.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _probar() async {
    Ajustes.servidorAgente.value = _ip.text.trim();
    Ajustes.claveAgente.value = _clave.text.trim();
    if (Ajustes.servidorAgente.value.isEmpty) {
      setState(() {
        _bien = false;
        _estado = 'Sin servidor: NANA contesta como siempre';
      });
      return;
    }
    setState(() {
      _probando = true;
      _estado = null;
    });
    final salud = await Servicios.agente.salud();
    if (!mounted) return;
    setState(() {
      _probando = false;
      _bien = salud != null && salud.claveOk;
      _estado = salud == null
          ? 'No lo encuentro. ¿Está prendido el agente en la laptop y en la misma red?'
          : salud.claveOk
          ? 'Conectado: ${salud.modelo}'
          : 'Lo encontré, pero la clave no coincide. Revisa la que sale en la laptop.';
    });
  }

  InputDecoration _caja(String pista, String etiqueta) => InputDecoration(
    hintText: pista,
    labelText: etiqueta,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Servidor de NANA (pruebas)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ColoresNana.tinta,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ip,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: const TextStyle(fontSize: 18),
          decoration: _caja('192.168.100.3', 'IP de la laptop'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clave,
          keyboardType: TextInputType.number,
          obscureText: true,
          autocorrect: false,
          style: const TextStyle(fontSize: 18),
          decoration: _caja('Vacía si no hay', 'Clave de la demo'),
          onSubmitted: (_) => _probar(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _probando ? null : _probar,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresNana.morado,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(_probando ? 'Probando…' : 'Guardar y probar'),
          ),
        ),
        if (_estado != null) ...[
          const SizedBox(height: 6),
          Text(
            _estado!,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _bien ? ColoresNana.ok : ColoresNana.alerta,
            ),
          ),
        ],
      ],
    );
  }
}
