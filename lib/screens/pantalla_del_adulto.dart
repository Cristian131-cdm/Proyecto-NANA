import 'package:flutter/material.dart';

import '../core/medicion.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../models/apariencia.dart';
import '../widgets/ajustes_texto.dart' show velocidadesVoz;
import '../widgets/aviso.dart';
import '../widgets/formulario.dart';
import '../widgets/tarjeta_dato.dart';

// El encargado principal decide cómo se ve NANA en el celular de la persona
// mayor. Se manda a su celular y se aplica solo; ella después puede cambiarlo
// en "Aa" y se respeta hasta el siguiente cambio de aquí.
class PantallaDelAdulto extends StatefulWidget {
  final String adulto;
  final String folio;
  const PantallaDelAdulto({
    super.key,
    required this.adulto,
    required this.folio,
  });

  static const letras = [
    (1.0, 'Normal'),
    (1.25, 'Grande'),
    (1.5, 'Muy grande'),
  ];

  @override
  State<PantallaDelAdulto> createState() => _PantallaDelAdultoState();
}

class _PantallaDelAdultoState extends State<PantallaDelAdulto> {
  Apariencia? _a; // null mientras carga
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    Servicios.repo.apariencia(widget.folio).first.then((a) {
      if (mounted) setState(() => _a = a ?? const Apariencia());
    });
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    try {
      await Servicios.repo.guardarApariencia(widget.folio, _a!);
      Medicion.tarea('pantalla_ajustada');
      if (!mounted) return;
      mostrarAviso(
        context,
        'Listo. Se aplica en el celular de ${widget.adulto}',
      );
      Navigator.pop(context);
    } on ErrorNana catch (e) {
      if (mounted) mostrarAviso(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _fila(Widget a, Widget b) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    ),
  );

  // Un botón grande que se prende y se apaga: dice «✓ Prendido» o «Apagado»
  // en palabras, no solo con color.
  Widget _mosaico(
    IconData icono,
    String titulo,
    bool prendido,
    VoidCallback cambiar,
  ) => Semantics(
    button: true,
    toggled: prendido,
    label: titulo,
    excludeSemantics: true,
    child: Material(
      color: prendido ? ColoresNana.moradoClaro : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: prendido ? ColoresNana.morado : const Color(0xFFDDD6F3),
          width: prendido ? 3 : 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(cambiar),
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: ColoresNana.morado, size: 32),
              const SizedBox(height: 4),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                prendido ? '✓ Prendido' : 'Apagado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: prendido ? ColoresNana.ok : ColoresNana.tintaSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final adulto = widget.adulto;
    return Scaffold(
      appBar: AppBar(title: Text('Pantalla de $adulto')),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Así se verá NANA en su celular',
                  style: TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
                ),
                const TituloSeccion('Letra'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (valor, nombre) in PantallaDelAdulto.letras)
                      ChoiceChip(
                        label: Text(
                          nombre,
                          style: TextStyle(fontSize: 16 * valor),
                        ),
                        selected: a.escalaTexto == valor,
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        selectedColor: ColoresNana.moradoClaro,
                        onSelected: (_) => setState(
                          () => _a = _a!.copyWith(escalaTexto: valor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botones grandes como los del «Aa» de la persona mayor.
                _fila(
                  _mosaico(
                    Icons.record_voice_over_outlined,
                    'Que le hable',
                    a.queMeHable,
                    () => _a = _a!.copyWith(queMeHable: !a.queMeHable),
                  ),
                  _mosaico(
                    Icons.contrast,
                    'Colores fuertes',
                    a.altoContraste,
                    () => _a = _a!.copyWith(altoContraste: !a.altoContraste),
                  ),
                ),
                const SizedBox(height: 10),
                _fila(
                  _mosaico(
                    Icons.motion_photos_off_outlined,
                    'Menos movimiento',
                    a.menosMovimiento,
                    () =>
                        _a = _a!.copyWith(menosMovimiento: !a.menosMovimiento),
                  ),
                  _mosaico(
                    Icons.touch_app,
                    'Contestar tocando',
                    a.contestarTocando,
                    () => _a = _a!.copyWith(
                      contestarTocando: !a.contestarTocando,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _fila(
                  _mosaico(
                    Icons.hearing,
                    'Oye NANA',
                    a.oyeNana,
                    () => _a = _a!.copyWith(oyeNana: !a.oyeNana),
                  ),
                  const SizedBox.shrink(),
                ),
                const TituloSeccion('Qué tan rápido le habla'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (valor, nombre) in velocidadesVoz)
                      ChoiceChip(
                        label: Text(
                          nombre,
                          style: const TextStyle(fontSize: 16),
                        ),
                        selected: (a.velocidadVoz - valor).abs() < 0.01,
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        selectedColor: ColoresNana.moradoClaro,
                        onSelected: (_) => setState(
                          () => _a = _a!.copyWith(velocidadVoz: valor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$adulto puede cambiarlo después en su botón «Aa»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: ColoresNana.tintaSuave,
                  ),
                ),
                const SizedBox(height: 12),
                BotonPrincipal(
                  texto: 'Guardar',
                  ocupado: _ocupado,
                  onPressed: _guardar,
                ),
              ],
            ),
    );
  }
}
