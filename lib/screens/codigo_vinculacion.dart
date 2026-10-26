import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/codigo.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/adulto.dart';
import '../widgets/aviso.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'panel_cuidador.dart';

String _hora(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
}

// El cuidador ve el código que el adulto escribe en su celular. En cuanto
// lo usa, la pantalla cambia sola.
class PantallaCodigo extends StatelessWidget {
  final CodigoVinculacion codigo;
  final String nombreAdulto;

  const PantallaCodigo({
    super.key,
    required this.codigo,
    required this.nombreAdulto,
  });

  @override
  Widget build(BuildContext context) {
    final visible = formatearCodigo(codigo.codigo);
    return StreamBuilder<bool>(
      stream: Servicios.repo.codigoUsado(codigo.codigo),
      builder: (context, snap) {
        if (snap.data == true) {
          return PantallaPaso(
            titulo: '¡Listo! Ya conectamos a $nombreAdulto',
            subtitulo: 'Lo que anote en su celular te va a aparecer aquí.',
            children: [
              const Icon(Icons.check_circle, color: ColoresNana.ok, size: 72),
              const SizedBox(height: 24),
              BotonPrincipal(
                texto: 'Ir a mi panel',
                onPressed: () => entrarA(context, const PanelCuidador()),
              ),
            ],
          );
        }
        return PantallaPaso(
          titulo: 'Código para $nombreAdulto',
          subtitulo:
              'Abre NANA en su celular, toca "Soy adulto mayor" y '
              'luego "Entrar con un código".',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: ColoresNana.moradoClaro,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Semantics(
                label: 'Código: ${codigo.codigo.split('').join(' ')}',
                excludeSemantics: true,
                child: Text(
                  visible,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: ColoresNana.morado,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sirve una sola vez, hasta mañana a las ${_hora(codigo.expira)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: BotonSecundario(
                    texto: 'Copiar',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codigo.codigo));
                      mostrarAviso(context, 'Código copiado');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotonSecundario(
                    texto: 'Compartir',
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Abre NANA, toca "Soy adulto mayor" y escribe '
                            'este código: $visible',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Esperando a que lo escriba…',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => entrarA(context, const PanelCuidador()),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(fontSize: 20),
              ),
              child: const Text('Lo hago después'),
            ),
          ],
        );
      },
    );
  }
}
