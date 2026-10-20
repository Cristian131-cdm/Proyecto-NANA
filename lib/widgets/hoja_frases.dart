import 'package:flutter/material.dart';

import '../core/tema.dart';

const frasesPorGrupo = {
  'Salud': [
    'Ya tomé mi medicina',
    'Me siento mal',
    'Me duele algo',
    'Tengo sueño',
    '¿Cuándo es mi cita?',
  ],
  'Comida': [
    'Ya desayuné',
    'Ya comí',
    'Ya cené',
    'Tengo hambre',
    'Ya tomé agua',
  ],
  'Ánimo': [
    'Me siento bien',
    'Me siento triste',
    'Estoy de buenas',
    'Algo me preocupa',
  ],
  'Familia': [
    'Quiero hablar con mi familia',
    '¿Viene alguien hoy?',
    'Extraño a mi familia',
  ],
  'Mi día': [
    '¿Qué sigue hoy?',
    'Necesito ayuda',
  ],
};

/// Abre la hoja con todas las frases. Regresa la frase que tocó, o null.
Future<String?> mostrarHojaFrases(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => const _HojaFrases(),
  );
}

class _HojaFrases extends StatelessWidget {
  const _HojaFrases();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D2EA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('¿Qué le quieres decir a NANA?',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 30),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            for (final grupo in frasesPorGrupo.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text(grupo.key,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ColoresNana.morado)),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: grupo.value
                    .map((f) => BotonFrase(
                          frase: f,
                          onTap: () => Navigator.pop(context, f),
                        ))
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

class BotonFrase extends StatelessWidget {
  final String frase;
  final VoidCallback onTap;

  const BotonFrase({super.key, required this.frase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ayuda = frase == 'Necesito ayuda';
    return ActionChip(
      label: Text(frase,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ayuda ? ColoresNana.alerta : ColoresNana.morado)),
      backgroundColor: ayuda ? ColoresNana.alertaClaro : ColoresNana.moradoClaro,
      side: ayuda
          ? const BorderSide(color: ColoresNana.alerta, width: 1.5)
          : BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      onPressed: onTap,
    );
  }
}
