import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ajustes.dart';
import '../core/lector.dart';
import '../core/medicion.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../core/voz.dart';
import '../widgets/aviso.dart';

/// «Voy a avisar a tu familia» con cuenta regresiva. Si la persona no la
/// cancela, al llegar a cero se avisa sola: así sirve aunque se haya caído y
/// no alcance el celular.
///
/// [porVoz]: la pidió hablando ("me caí", "ayuda"). Cuenta 20 s, NANA lo
/// dice en voz alta y escucha "estoy bien" o "avísales". Si nadie contesta,
/// la alerta sale como 'sin_respuesta', la más grave para la familia.
/// Sin [porVoz] (tocó «Necesito ayuda»): 5 s solo para deshacer un toque
/// sin querer, y sale como 'boton'.
///
/// Regresa true si se avisó.
class AvisoAyuda extends StatefulWidget {
  final String folio;
  final String nombre;
  final bool porVoz;

  const AvisoAyuda({
    super.key,
    required this.folio,
    this.nombre = '',
    this.porVoz = false,
  });

  static const segundosVoz = 20;
  static const segundosBoton = 5;

  @override
  State<AvisoAyuda> createState() => _AvisoAyudaState();
}

class _AvisoAyudaState extends State<AvisoAyuda> {
  late final int _total = widget.porVoz
      ? AvisoAyuda.segundosVoz
      : AvisoAyuda.segundosBoton;
  late int _restan = _total;
  Timer? _reloj;
  Timer? _arranque;
  bool _cerrado = false;
  bool _repetido = false;

  String get _hola => widget.nombre.isEmpty ? '' : '${widget.nombre}, ';

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    _arranque = Timer(const Duration(milliseconds: 800), _empezar);
  }

  // La pantalla de antes (la plática, NanaEscucha) se termina de cerrar un
  // momento DESPUÉS de que esta se abre, y al cerrarse calla a NANA y suelta
  // el micrófono. Si NANA hablara de inmediato, la cortaría: se espera a que
  // termine la transición (por eso arranca con [_arranque], 0.8 s después).
  Future<void> _empezar() async {
    if (_cerrado || !mounted) return;
    if (widget.porVoz) {
      await _conversar();
    } else {
      await nanaDice(
        context,
        'Voy a avisarle a tu familia. Si fue sin querer, toca: estoy bien.',
        siempre: true,
      );
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _arranque?.cancel();
    if (!_cerrado) Servicios.voz.callar();
    _cerrado = true;
    Servicios.voz.dejarDeEscuchar();
    super.dispose();
  }

  void _tic() {
    if (_cerrado || !mounted) return;
    setState(() => _restan--);
    if (_restan <= 0) {
      // Nadie lo canceló. Si la pidió hablando y luego no contestó, puede
      // que no se pueda mover: la familia lo ve como lo más urgente.
      _avisar(widget.porVoz ? 'sin_respuesta' : 'boton');
    } else if (_restan % 5 == 0) {
      HapticFeedback.vibrate();
    }
  }

  // Escucha mientras corre la cuenta. A la mitad lo vuelve a decir.
  Future<void> _conversar() async {
    await nanaDice(
      context,
      '${_hola}voy a avisarle a tu familia. Si estás bien, di: estoy bien.',
      siempre: true,
    );
    // Quien no habla contesta tocando: no se prende el micrófono.
    if (Ajustes.sinVoz.value) return;
    while (true) {
      if (_cerrado || !mounted) return;
      if (!_repetido && _restan <= _total ~/ 2) {
        _repetido = true;
        await nanaDice(
          context,
          'Si estás bien, di: estoy bien. Si no, yo les aviso.',
          siempre: true,
        );
        if (_cerrado || !mounted) return;
      }
      final hastaRepetir = _repetido ? _restan : _restan - _total ~/ 2;
      final oido = await Servicios.voz.escuchar(
        maximo: Duration(seconds: math.max(1, hastaRepetir)),
        sirve: (t) => entender(t, respuestasAviso) != null,
      );
      if (_cerrado || !mounted) return;
      switch (entender(oido, respuestasAviso)) {
        case RespuestaAviso.avisar:
          _avisar('voz');
          return;
        case RespuestaAviso.cancelar:
          _cancelar();
          return;
        case RespuestaAviso.no:
          await nanaDice(
            context,
            '¿Estás bien? Di: estoy bien. O di: avísales.',
            siempre: true,
          );
        case null:
          // No oyó nada (o no hay micrófono): se espera un poco y sigue
          // escuchando hasta que se acabe la cuenta.
          await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _avisar(String como) async {
    if (_cerrado) return;
    _cerrado = true;
    _reloj?.cancel();
    Servicios.voz.dejarDeEscuchar();
    Medicion.tarea('pidio_ayuda');
    final llego = await Servicios.repo.pedirAyuda(widget.folio, como: como);
    if (!mounted) return;
    final texto = llego
        ? 'Ya le avisé a tu familia. Quédate tranquila, ya saben.'
        : 'No hay internet. Lo mando en cuanto haya.';
    nanaDice(context, texto, siempre: true);
    mostrarAviso(
      context,
      llego
          ? 'Listo, ya le avisé a tu familia'
          : 'No hay internet. Lo mando en cuanto haya',
    );
    Navigator.pop(context, true);
  }

  void _cancelar() {
    if (_cerrado) return;
    _cerrado = true;
    _reloj?.cancel();
    Servicios.voz.dejarDeEscuchar();
    nanaDice(context, 'Qué bueno que estás bien. Aquí sigo.', siempre: true);
    mostrarAviso(context, 'No le avisé a nadie');
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final escucha = widget.porVoz && !Ajustes.sinVoz.value;
    return Scaffold(
      backgroundColor: ColoresNana.urgente,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, caja) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: caja.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    children: [
                      const Spacer(),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: const Text(
                          'Voy a avisar a tu familia',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Cuenta(restan: _restan, total: _total),
                      const SizedBox(height: 20),
                      Text(
                        escucha
                            ? 'Si estás bien, di «estoy bien»'
                            : 'Si fue sin querer, toca «Estoy bien»',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (escucha) ...[
                        const SizedBox(height: 12),
                        ValueListenableBuilder<bool>(
                          valueListenable: Servicios.voz.escuchando,
                          builder: (context, escuchando, _) => Opacity(
                            opacity: escuchando ? 1 : 0,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, color: Colors.white, size: 26),
                                SizedBox(width: 8),
                                Text(
                                  'Te escucho',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 84,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _avisar(widget.porVoz ? 'voz' : 'boton'),
                          icon: const Icon(Icons.notifications_active, size: 34),
                          label: const Text('Avisar ya'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ColoresNana.urgente,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 80,
                        child: OutlinedButton.icon(
                          onPressed: _cancelar,
                          icon: const Icon(Icons.check, size: 32),
                          label: const Text('Estoy bien'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 3,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    );
  }
}

// El círculo con los segundos que faltan. Con «Menos movimiento» el aro no
// se anima entre segundo y segundo: solo cambia el número.
class _Cuenta extends StatelessWidget {
  final int restan;
  final int total;
  const _Cuenta({required this.restan, required this.total});

  @override
  Widget build(BuildContext context) {
    final valor = total == 0 ? 0.0 : restan / total;
    final quieto = Ajustes.menosMovimiento.value;
    return Semantics(
      label: 'Faltan $restan segundos',
      excludeSemantics: true,
      child: SizedBox(
        width: 170,
        height: 170,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: quieto
                  ? CircularProgressIndicator(
                      value: valor,
                      strokeWidth: 12,
                      color: Colors.white,
                      backgroundColor: ColoresNana.urgenteOscuro,
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween(end: valor),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 12,
                        color: Colors.white,
                        backgroundColor: ColoresNana.urgenteOscuro,
                      ),
                    ),
            ),
            Text(
              '$restan',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
