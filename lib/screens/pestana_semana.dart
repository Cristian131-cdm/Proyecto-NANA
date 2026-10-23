import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/tarjeta_dato.dart';

class PestanaSemana extends StatelessWidget {
  final String adulto;
  const PestanaSemana({super.key, required this.adulto});

  static const dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static const _nombresDias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
  ];

  // Texto que se comparte por WhatsApp, SMS, etc. Solo datos, sin consejos.
  static String resumen(String adulto) {
    const tomas = DatosEjemplo.tomasSemana;
    const animo = DatosEjemplo.animoSemana;
    final total = tomas.fold(0, (a, b) => a + b);
    final faltas = [
      for (var i = 0; i < tomas.length; i++)
        if (tomas[i] < 2) _nombresDias[i],
    ];
    final animos = [
      for (var i = 0; i < animo.length; i++)
        '${_nombresDias[i]} ${CaritasAnimo.etiquetas[animo[i]].toLowerCase()}',
    ];
    return [
      'Resumen de la semana de $adulto (NANA)',
      'Medicinas a tiempo: $total de ${tomas.length * 2}'
          '${faltas.isEmpty ? '' : ' · faltó el ${faltas.join(' y el ')}'}',
      'Cómo se sintió: ${animos.join(', ')}',
      'NANA solo registra, recuerda y alerta. No da recomendaciones médicas.',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    const tomas = DatosEjemplo.tomasSemana;
    final total = tomas.fold(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Text('Del 13 al 19 de octubre',
            style: TextStyle(fontSize: 16, color: Color(0xFF6B6485))),
        const TituloSeccion('Medicinas a tiempo'),
        // Sin altura fija: la caja crece con la letra. Con una altura fija,
        // la letra grande del celular desbordaba las columnas.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          decoration: _caja,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < tomas.length; i++)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${tomas[i]}/2',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B6485))),
                      const SizedBox(height: 4),
                      Container(
                        width: 26,
                        height: 90.0 * tomas[i] / 2,
                        decoration: BoxDecoration(
                          color: tomas[i] == 2
                              ? ColoresNana.lila
                              : const Color(0xFFE8B260),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(dias[i],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const TituloSeccion('Cómo se sintió'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: _caja,
          child: Row(
            children: [
              for (var i = 0; i < dias.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        CaritasAnimo.iconos[DatosEjemplo.animoSemana[i]],
                        size: 32,
                        color:
                            CaritasAnimo.colores[DatosEjemplo.animoSemana[i]],
                      ),
                      const SizedBox(height: 4),
                      Text(dias[i],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const TituloSeccion('Lo importante'),
        TarjetaDato(
          icono: Icons.medication,
          titulo: '$total de ${tomas.length * 2} tomas',
          subtitulo: 'Se le pasaron la del miércoles y la del domingo',
          color: ColoresNana.alerta,
        ),
        const TarjetaDato(
          icono: Icons.sentiment_dissatisfied,
          titulo: 'El domingo dijo "Me siento mal"',
          subtitulo: 'A las 7:40 pm',
          color: ColoresNana.alerta,
        ),
        const TarjetaDato(
          icono: Icons.directions_walk,
          titulo: 'Caminó 4 de 5 días',
          subtitulo: 'El viernes no salió',
          color: ColoresNana.azul,
        ),
        const SizedBox(height: 12),
        BotonSecundario(
          icono: Icons.share,
          texto: 'Mandar resumen a la familia',
          onPressed: () => SharePlus.instance
              .share(ShareParams(text: resumen(adulto))),
        ),
      ],
    );
  }

  static final _caja = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: ColoresNana.moradoClaro, width: 2),
  );
}
