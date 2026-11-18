import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/lector.dart';
import '../core/tema.dart';
import 'interruptor_huella.dart';
import 'mascota_nana.dart';

// (ícono, título, explicación, preferencia).
// Lo que la persona mayor elige en la encuesta del primer día: lo mismo que
// los botones de su «Aa», sin la letra (que es el paso 1 de la encuesta).
final modosAdulto = [
  (
    Icons.record_voice_over,
    'Que me hable',
    'NANA lee en voz alta y te pregunta',
    Ajustes.queMeHable,
  ),
  (
    Icons.contrast,
    'Colores fuertes',
    'Más contraste para ver mejor',
    Ajustes.altoContraste,
  ),
  (
    Icons.hearing,
    'Oye NANA',
    'Con NANA abierta, dices «Oye NANA» y te escucha',
    Ajustes.oyeNana,
  ),
];

// Las opciones de «Aa» de quien cuida (letra aparte).
final modosDeUso = [
  (
    Icons.contrast,
    'Colores más fuertes',
    'Más contraste para ver mejor',
    Ajustes.altoContraste,
  ),
  (
    Icons.motion_photos_off_outlined,
    'Menos movimiento',
    'Sin animaciones ni cosas que se muevan',
    Ajustes.menosMovimiento,
  ),
  (
    Icons.hearing,
    'Llamar a NANA con la voz',
    'Con NANA abierta, di «Oye NANA» y te escucha',
    Ajustes.oyeNana,
  ),
];

// Tamaños de letra: (escala, nombre).
const tamanosLetra = [(1.0, 'Normal'), (1.25, 'Grande'), (1.5, 'Muy grande')];

// Velocidades de la voz: (valor, nombre).
const velocidadesVoz = [(0.7, 'Despacio'), (1.0, 'Normal'), (1.3, 'Rápido')];

// onCerrarSesion: si viene, sale «Salir de NANA en este celular» dentro de
// «Más opciones». paraCuidador: la hoja de quien cuida (letra, colores,
// movimiento, «Oye NANA» y huella).
void mostrarAjustesTexto(
  BuildContext context, {
  VoidCallback? onCerrarSesion,
  bool paraCuidador = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => paraCuidador
        ? const _HojaCuidador()
        : HojaAjustesAdulto(onCerrarSesion: onCerrarSesion),
  );
}

// «Ajustar NANA» de la persona mayor: cuatro botones grandes y nada de
// explicaciones escritas. Al tocar uno, NANA dice en voz alta lo que hizo.
// Lo demás (menos movimiento, contestar tocando) lo pone el encargado desde
// «Pantalla del adulto»; huella y salir quedan en «Más opciones».
class HojaAjustesAdulto extends StatefulWidget {
  final VoidCallback? onCerrarSesion;
  const HojaAjustesAdulto({super.key, this.onCerrarSesion});

  @override
  State<HojaAjustesAdulto> createState() => _HojaAjustesAdultoState();
}

class _HojaAjustesAdultoState extends State<HojaAjustesAdulto> {
  String _dice = 'Toca lo que quieras cambiar';
  bool _masOpciones = false;

  void _decir(String texto) {
    setState(() => _dice = texto);
    nanaDice(context, texto, siempre: true);
  }

  int get _letra {
    final v = Ajustes.escalaTexto.value;
    var mejor = 0;
    for (var i = 1; i < tamanosLetra.length; i++) {
      if ((tamanosLetra[i].$1 - v).abs() < (tamanosLetra[mejor].$1 - v).abs()) {
        mejor = i;
      }
    }
    return mejor;
  }

  void _cambiarLetra() {
    final (valor, nombre) = tamanosLetra[(_letra + 1) % tamanosLetra.length];
    Ajustes.escalaTexto.value = valor;
    _decir('Listo, ahora la letra es ${nombre.toLowerCase()}');
  }

  void _alternar(ValueNotifier<bool> n, String prendido, String apagado) {
    n.value = !n.value;
    _decir(n.value ? prendido : apagado);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Ajustes.escalaTexto,
        Ajustes.queMeHable,
        Ajustes.altoContraste,
        Ajustes.oyeNana,
        Ajustes.velocidadVoz,
      ]),
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ajustar NANA',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: ColoresNana.morado,
                ),
              ),
              const SizedBox(height: 12),
              // Lo que NANA acaba de decir, también escrito.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ColoresNana.moradoClaro,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const ExcludeSemantics(
                      child: MascotaNana(tamano: 40, conVoz: false),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _dice,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: ColoresNana.morado,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _fila(
                _BotonAjuste(
                  titulo: 'Letra',
                  estado: tamanosLetra[_letra].$2,
                  dibujo: MediaQuery.withNoTextScaling(
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 32.0 + 10 * _letra,
                        height: 1,
                        fontWeight: FontWeight.bold,
                        color: ColoresNana.morado,
                      ),
                    ),
                  ),
                  onTap: _cambiarLetra,
                ),
                _BotonAjuste(
                  titulo: 'Que me hable',
                  prendido: Ajustes.queMeHable.value,
                  dibujo: const Icon(
                    Icons.record_voice_over,
                    size: 42,
                    color: ColoresNana.morado,
                  ),
                  onTap: () => _alternar(
                    Ajustes.queMeHable,
                    'Listo, ahora te hablo',
                    'Listo, ya no te leo',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _fila(
                _BotonAjuste(
                  titulo: 'Colores fuertes',
                  prendido: Ajustes.altoContraste.value,
                  dibujo: const Icon(
                    Icons.contrast,
                    size: 42,
                    color: ColoresNana.morado,
                  ),
                  onTap: () => _alternar(
                    Ajustes.altoContraste,
                    'Listo, colores más fuertes',
                    'Listo, colores normales',
                  ),
                ),
                _BotonAjuste(
                  titulo: 'Oye NANA',
                  prendido: Ajustes.oyeNana.value,
                  dibujo: const Icon(
                    Icons.hearing,
                    size: 42,
                    color: ColoresNana.morado,
                  ),
                  onTap: () => _alternar(
                    Ajustes.oyeNana,
                    'Listo, dime «Oye NANA» cuando me necesites',
                    'Listo, ya no te escucho',
                  ),
                ),
              ),
              if (Ajustes.queMeHable.value) ...[
                const SizedBox(height: 14),
                _Velocidad(
                  actual: Ajustes.velocidadVoz.value,
                  onElegir: (valor, nombre) {
                    Ajustes.velocidadVoz.value = valor;
                    _decir(
                      nombre == 'Normal'
                          ? 'Así hablo normal'
                          : 'Así hablo ${nombre.toLowerCase()}',
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.morado,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Listo'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _masOpciones = !_masOpciones),
                icon: Icon(
                  _masOpciones ? Icons.expand_less : Icons.expand_more,
                  size: 28,
                ),
                label: const Text('Más opciones'),
                style: TextButton.styleFrom(
                  foregroundColor: ColoresNana.tintaSuave,
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_masOpciones) ...[
                const InterruptorHuella(),
                if (widget.onCerrarSesion case final salir?) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        salir();
                      },
                      icon: const Icon(Icons.logout, size: 26),
                      label: const Text('Salir de NANA en este celular'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresNana.alerta,
                        side: const BorderSide(
                          color: ColoresNana.alerta,
                          width: 2,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Dos botones del mismo alto, lado a lado.
  Widget _fila(Widget a, Widget b) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    ),
  );
}

// Botón grande cuadrado: dibujo, nombre y cómo está («✓ Prendido» o
// «Apagado» en palabras, no solo con color). Sin [prendido], muestra
// [estado] (la letra).
class _BotonAjuste extends StatelessWidget {
  final String titulo;
  final Widget dibujo;
  final bool? prendido;
  final String? estado;
  final VoidCallback onTap;

  const _BotonAjuste({
    required this.titulo,
    required this.dibujo,
    required this.onTap,
    this.prendido,
    this.estado,
  });

  @override
  Widget build(BuildContext context) {
    final marcado = prendido ?? true;
    final texto = estado ?? (prendido! ? '✓ Prendido' : 'Apagado');
    return Semantics(
      button: true,
      toggled: prendido,
      label: estado == null ? titulo : '$titulo: $estado. Toca para cambiar',
      excludeSemantics: true,
      child: Material(
        color: prendido == true ? ColoresNana.moradoClaro : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: marcado ? ColoresNana.morado : const Color(0xFFD9D2EA),
            width: marcado ? 3 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 54, child: Center(child: dibujo)),
                const SizedBox(height: 6),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: prendido == false
                        ? ColoresNana.tintaSuave
                        : prendido == true
                        ? ColoresNana.ok
                        : ColoresNana.morado,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// «¿Qué tan rápido te hablo?»: tres botones en vez de una barra.
class _Velocidad extends StatelessWidget {
  final double actual;
  final void Function(double valor, String nombre) onElegir;
  const _Velocidad({required this.actual, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    // La más cercana a lo guardado (antes había 5 velocidades).
    final elegida = velocidadesVoz.reduce(
      (a, b) => (a.$1 - actual).abs() <= (b.$1 - actual).abs() ? a : b,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9D2EA), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Qué tan rápido te hablo?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (valor, nombre) in velocidadesVoz)
                Semantics(
                  button: true,
                  selected: elegida.$1 == valor,
                  child: ChoiceChip(
                    label: Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: elegida.$1 == valor,
                    showCheckmark: false,
                    selectedColor: ColoresNana.moradoClaro,
                    side: BorderSide(
                      color: elegida.$1 == valor
                          ? ColoresNana.morado
                          : const Color(0xFFD9D2EA),
                      width: elegida.$1 == valor ? 3 : 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    onSelected: (_) => onElegir(valor, nombre),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// «Aa» de quien cuida: letra y las opciones que le sirven a cualquiera.
class _HojaCuidador extends StatelessWidget {
  const _HojaCuidador();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lectura y accesibilidad',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tamaño de letra',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<double>(
              valueListenable: Ajustes.escalaTexto,
              builder: (context, actual, _) => Row(
                children: [
                  for (final (i, (valor, nombre)) in tamanosLetra.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Semantics(
                          button: true,
                          selected: actual == valor,
                          label: 'Letra $nombre',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Ajustes.escalaTexto.value = valor,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: actual == valor
                                    ? ColoresNana.moradoClaro
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: actual == valor
                                      ? ColoresNana.morado
                                      : const Color(0xFFD9D2EA),
                                  width: actual == valor ? 3 : 1,
                                ),
                              ),
                              child: ExcludeSemantics(
                                child: Column(
                                  children: [
                                    Text(
                                      'Aa',
                                      style: TextStyle(
                                        fontSize: 22.0 + 6 * i,
                                        fontWeight: FontWeight.bold,
                                        color: ColoresNana.morado,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      nombre,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: actual == valor
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final m in modosDeUso)
              ValueListenableBuilder<bool>(
                valueListenable: m.$4,
                builder: (context, encendido, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(m.$1, color: ColoresNana.morado, size: 30),
                  title: Text(
                    m.$2,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(m.$3, style: const TextStyle(fontSize: 15)),
                  value: encendido,
                  onChanged: (v) => m.$4.value = v,
                ),
              ),
            const InterruptorHuella(),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande que se marca o desmarca. Lleva ícono, texto y palomita para
/// que no dependa solo del color.
class TarjetaModo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool marcada;
  final VoidCallback onTap;

  const TarjetaModo({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.marcada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: marcada,
        child: Material(
          color: marcada ? ColoresNana.moradoClaro : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: marcada ? ColoresNana.morado : const Color(0xFFD9D2EA),
              width: marcada ? 3 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icono, size: 36, color: ColoresNana.morado),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(detalle, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  Icon(
                    marcada ? Icons.check_box : Icons.check_box_outline_blank,
                    color: marcada
                        ? ColoresNana.morado
                        : const Color(0xFFB9B2CC),
                    size: 34,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
