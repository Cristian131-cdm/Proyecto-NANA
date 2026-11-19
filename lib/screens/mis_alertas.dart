import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/tema.dart';
import '../widgets/con_encargado.dart';

// Qué le avisa NANA a quien cuida, solo en ESTE celular. Las reglas de la
// familia (Familia y alertas) siguen igual para los demás.
class MisAlertas extends StatelessWidget {
  final String adulto;
  const MisAlertas({super.key, required this.adulto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis alertas')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Qué te avisa NANA de $adulto en este celular.',
              style: const TextStyle(fontSize: 19, color: ColoresNana.tinta),
            ),
            const SizedBox(height: 14),
            // Material (no Container con color) para que se vea el toque.
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: ColoresNana.moradoClaro, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Semantics(
                    label: 'Pidió ayuda. Siempre suena. No se puede apagar.',
                    excludeSemantics: true,
                    child: Container(
                      color: ColoresNana.alertaClaro,
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pidió ayuda',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Siempre suena. No se puede apagar.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: ColoresNana.alerta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.lock_outline, color: ColoresNana.alerta),
                        ],
                      ),
                    ),
                  ),
                  _Interruptor(
                    texto: 'Frases que dice $adulto',
                    callar: Ajustes.callarFrases,
                  ),
                  _Interruptor(
                    texto: 'Medicina sin confirmar',
                    callar: Ajustes.callarMedicina,
                  ),
                  _Interruptor(
                    texto: 'Sin noticias en el día',
                    callar: Ajustes.callarSinNoticias,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AvisoCandado(
              'Apagar una aquí no la apaga para el resto de la familia.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  final String texto;
  final ValueNotifier<bool> callar;
  const _Interruptor({required this.texto, required this.callar});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: callar,
      builder: (context, callada, _) => Column(
        children: [
          const Divider(height: 1, color: ColoresNana.moradoClaro),
          SwitchListTile(
            value: !callada,
            onChanged: (avisa) => callar.value = !avisa,
            activeThumbColor: ColoresNana.morado,
            minTileHeight: 68,
            title: Text(
              texto,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
