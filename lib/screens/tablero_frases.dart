import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/hoja_frases.dart';
import 'senas.dart';

// "Decir": para quien no habla. Cada cuadro es una frase de hoja_frases.dart
// con un ícono grande; tocarlo es decirlo.
class TableroFrases extends StatelessWidget {
  final ValueChanged<String> onFrase;
  // "Mejor quiero hablar": abre Hablar con NANA con el micrófono.
  final VoidCallback? onHablar;
  const TableroFrases({super.key, required this.onFrase, this.onHablar});

  static const cuadros = [
    ('Ya tomé mi medicina', Icons.medication),
    ('Ya comí', Icons.restaurant),
    ('Tengo hambre', Icons.lunch_dining),
    ('Me duele algo', Icons.healing),
    ('Me siento mal', Icons.sick),
    ('Me siento bien', Icons.sentiment_very_satisfied),
    ('Tengo sueño', Icons.bedtime),
    ('Quiero hablar con mi familia', Icons.family_restroom),
  ];

  void _decir(BuildContext context, String frase) {
    Navigator.pop(context);
    onFrase(frase);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Qué me quieres decir?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (onHablar case final hablar?) ...[
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  hablar();
                },
                icon: const Icon(Icons.mic, size: 30),
                label: const Text('Mejor quiero hablar'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.azul,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // De dos en dos; cada fila crece con la letra grande en vez de cortarla.
          for (var i = 0; i < cuadros.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (frase, icono) in cuadros.skip(i).take(2)) ...[
                      if (frase != cuadros[i].$1) const SizedBox(width: 12),
                      Expanded(
                        child: _Cuadro(
                          frase: frase,
                          icono: icono,
                          onTap: () => _decir(context, frase),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          _Cuadro(
            frase: 'Necesito ayuda',
            icono: Icons.notifications_active,
            ayuda: true,
            onTap: () => _decir(context, 'Necesito ayuda'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final f = await mostrarHojaFrases(context);
                    if (f != null && context.mounted) _decir(context, f);
                  },
                  icon: const Icon(Icons.add, size: 28),
                  label: const Text('Más frases'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirHablarConSenas(context),
                  icon: const Icon(Icons.videocam_outlined, size: 28),
                  label: const Text('Con señas'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cuadro extends StatelessWidget {
  final String frase;
  final IconData icono;
  final bool ayuda;
  final VoidCallback onTap;

  const _Cuadro({
    required this.frase,
    required this.icono,
    required this.onTap,
    this.ayuda = false,
  });

  @override
  Widget build(BuildContext context) {
    final frente = ayuda ? ColoresNana.alerta : ColoresNana.morado;
    return Material(
      color: ayuda ? ColoresNana.alertaClaro : ColoresNana.moradoClaro,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: ayuda
            ? const BorderSide(color: ColoresNana.alerta, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 48, color: frente),
              const SizedBox(height: 8),
              Text(
                frase,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: frente,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
