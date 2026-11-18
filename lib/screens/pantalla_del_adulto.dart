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

  Widget _interruptor(
    IconData icono,
    String titulo,
    String detalle,
    bool valor,
    ValueChanged<bool> onCambio,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SuperficieCuidador(
      // Material propio: sin él, la tarjeta tapa el efecto al tocar.
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icono, color: ColoresNana.morado, size: 28),
          title: Text(
            titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(detalle, style: const TextStyle(fontSize: 15)),
          value: valor,
          activeThumbColor: ColoresNana.morado,
          onChanged: onCambio,
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
                Text(
                  'Así se verá NANA en el celular de $adulto. Después '
                  '$adulto puede cambiarlo desde su botón "Aa".',
                  style: const TextStyle(
                    fontSize: 16,
                    color: ColoresNana.tintaSuave,
                  ),
                ),
                const TituloSeccion('Tamaño de letra'),
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
                const TituloSeccion('Cómo la ayuda NANA'),
                _interruptor(
                  Icons.contrast,
                  'Colores más fuertes',
                  'Más contraste y letra en negritas',
                  a.altoContraste,
                  (v) => setState(() => _a = _a!.copyWith(altoContraste: v)),
                ),
                _interruptor(
                  Icons.record_voice_over_outlined,
                  'Que NANA le hable',
                  'Lee en voz alta cada pantalla al abrirla',
                  a.queMeHable,
                  (v) => setState(() => _a = _a!.copyWith(queMeHable: v)),
                ),
                _interruptor(
                  Icons.motion_photos_off_outlined,
                  'Menos movimiento',
                  'Sin animaciones',
                  a.menosMovimiento,
                  (v) => setState(() => _a = _a!.copyWith(menosMovimiento: v)),
                ),
                _interruptor(
                  Icons.touch_app,
                  'Contestar tocando',
                  'Para quien no habla: en vez de usar la voz, toca lo que '
                      'quiere decir',
                  a.contestarTocando,
                  (v) => setState(() => _a = _a!.copyWith(contestarTocando: v)),
                ),
                _interruptor(
                  Icons.hearing,
                  'Llamar a NANA con la voz',
                  'Con NANA abierta, dice «Oye NANA» y ella le escucha. '
                      'Se reconoce dentro de su celular, no se graba.',
                  a.oyeNana,
                  (v) => setState(() => _a = _a!.copyWith(oyeNana: v)),
                ),
                const TituloSeccion('Qué tan rápido le habla NANA'),
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
                const SizedBox(height: 16),
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
