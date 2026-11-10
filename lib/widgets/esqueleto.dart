import 'package:flutter/material.dart';

import '../core/tema.dart';

// Mientras carga: tarjetas grises con la forma de lo que viene, que laten
// suave. Con "reducir animaciones" se quedan quietas.
class EsqueletoCarga extends StatefulWidget {
  final int tarjetas;
  const EsqueletoCarga({super.key, this.tarjetas = 3});

  @override
  State<EsqueletoCarga> createState() => _EsqueletoCargaState();
}

class _EsqueletoCargaState extends State<EsqueletoCarga>
    with SingleTickerProviderStateMixin {
  late final _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _latido.stop();
      _latido.value = 0.5;
    } else if (!_latido.isAnimating) {
      _latido.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  Widget _caja(double alto, {double? ancho}) => Container(
    height: alto,
    width: ancho,
    decoration: BoxDecoration(
      color: ColoresNana.moradoClaro,
      borderRadius: BorderRadius.circular(20),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween(begin: 0.45, end: 1.0).animate(_latido),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: ColoresNana.moradoClaro,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _caja(22, ancho: 180),
                        const SizedBox(height: 10),
                        _caja(14, ancho: 120),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _caja(180),
              for (var i = 1; i < widget.tarjetas; i++) ...[
                const SizedBox(height: 14),
                _caja(84),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
