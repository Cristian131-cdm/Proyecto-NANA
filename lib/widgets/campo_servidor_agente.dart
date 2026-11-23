import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/servicios.dart';
import '../core/tema.dart';

/// «Servidor de NANA (pruebas)»: la IP de la laptop donde corre el agente.
/// Va en «Más opciones» porque solo se usa para probar y en la demo.
class CampoServidorAgente extends StatefulWidget {
  const CampoServidorAgente({super.key});

  @override
  State<CampoServidorAgente> createState() => _CampoServidorAgenteState();
}

class _CampoServidorAgenteState extends State<CampoServidorAgente> {
  late final _control = TextEditingController(
    text: Ajustes.servidorAgente.value,
  );
  String? _estado;
  bool _probando = false;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Future<void> _probar() async {
    Ajustes.servidorAgente.value = _control.text.trim();
    if (Ajustes.servidorAgente.value.isEmpty) {
      setState(() => _estado = 'Sin servidor: NANA contesta como siempre');
      return;
    }
    setState(() {
      _probando = true;
      _estado = null;
    });
    final modelo = await Servicios.agente.salud();
    if (!mounted) return;
    setState(() {
      _probando = false;
      _estado = modelo != null ? 'Conectado: $modelo' : 'No lo encuentro. ¿Está prendido el agente en la laptop y en la misma red?';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bien = _estado?.startsWith('Conectado') ?? false;
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
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _control,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '192.168.100.3',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _probar(),
              ),
            ),
            const SizedBox(width: 8),
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
                child: Text(_probando ? '…' : 'Probar'),
              ),
            ),
          ],
        ),
        if (_estado != null) ...[
          const SizedBox(height: 6),
          Text(
            _estado!,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: bien ? ColoresNana.ok : ColoresNana.alerta,
            ),
          ),
        ],
      ],
    );
  }
}
