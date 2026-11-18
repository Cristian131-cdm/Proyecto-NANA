import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/despertador.dart';
import '../core/servicios.dart';
import '../core/tema.dart';

// Envuelve una pantalla de inicio (la del adulto y la del encargado): si
// «Oye NANA» está prendido, la pantalla está hasta arriba y la app está
// abierta, espera la frase y llama a [alOir]. En cuanto se abre otra
// pantalla, se minimiza la app o se apaga el ajuste, suelta el micrófono.
class EsperaOyeNana extends StatefulWidget {
  final VoidCallback alOir;
  final Widget child;

  const EsperaOyeNana({super.key, required this.alOir, required this.child});

  @override
  State<EsperaOyeNana> createState() => _EsperaOyeNanaState();
}

class _EsperaOyeNanaState extends State<EsperaOyeNana>
    with RouteAware, WidgetsBindingObserver {
  ModalRoute<void>? _ruta;
  bool _hastaArriba = true;
  bool _abierta = true;
  bool _esperando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Ajustes.oyeNana.addListener(_revisar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta != _ruta) {
      if (_ruta != null) rutasNana.unsubscribe(this);
      _ruta = ruta;
      if (ruta != null) rutasNana.subscribe(this, ruta);
    }
    _revisar();
  }

  @override
  void dispose() {
    rutasNana.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    Ajustes.oyeNana.removeListener(_revisar);
    if (_esperando) Servicios.despertador.parar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _abierta = state == AppLifecycleState.resumed;
    _revisar();
  }

  // Se abrió otra pantalla encima (plática, recordatorio, Mi día…).
  @override
  void didPushNext() {
    _hastaArriba = false;
    _revisar();
  }

  // Se cerró la de encima: esta vuelve a estar hasta arriba.
  @override
  void didPopNext() {
    _hastaArriba = true;
    _revisar();
  }

  void _revisar() {
    if (!mounted) return;
    final debe = Ajustes.oyeNana.value && _hastaArriba && _abierta;
    if (debe && !_esperando) {
      _esperando = true;
      Servicios.despertador.empezar(_oyo);
    } else if (!debe && _esperando) {
      _esperando = false;
      Servicios.despertador.parar();
    }
  }

  void _oyo() {
    _esperando = false;
    if (!mounted) return;
    widget.alOir();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Aviso chiquito en la barra de arriba mientras NANA espera «Oye NANA».
// Sirve para que se sepa que el micrófono está en uso.
class AvisoOyeNana extends StatelessWidget {
  const AvisoOyeNana({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Servicios.despertador.activo,
      builder: (context, activo, _) => activo
          ? Semantics(
              label: 'NANA te escucha. Di: Oye NANA',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ColoresNana.moradoClaro,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hearing, size: 20, color: ColoresNana.morado),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Di «Oye NANA»',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ColoresNana.morado,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
