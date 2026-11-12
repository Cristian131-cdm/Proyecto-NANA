import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/lector.dart';
import '../core/senas/catalogo.dart';
import '../core/senas/clasificador.dart';
import '../core/senas/ojo.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../widgets/aviso.dart';

/// Hablar con señas: la cámara ve la mano y NANA propone lo que entendió
/// ("¿Quisiste decir: me duele algo?"). La persona confirma con el pulgar
/// arriba, con la seña de sí o tocando. Regresa la frase confirmada, o null.
///
/// La cámara solo está prendida en esta pantalla y se apaga al salir. Todo
/// pasa en el celular: no se graba ni se manda imagen.
class CamaraSenas extends StatefulWidget {
  const CamaraSenas({super.key});

  @override
  State<CamaraSenas> createState() => _CamaraSenasState();
}

class _CamaraSenasState extends State<CamaraSenas> {
  late final OjoSenas _ojo = Servicios.crearOjo();
  final _sostenida = SenaSostenida();
  StreamSubscription<ManoVista?>? _sub;
  ClasificadorSenas _clasificador = const ClasificadorSenas([]);

  bool _prendiendo = true;
  String? _error;
  bool _hayMano = false;
  // La frase que NANA propone y espera que le confirmen.
  String? _propuesta;

  @override
  void initState() {
    super.initState();
    _prender();
  }

  Future<void> _prender() async {
    await Servicios.senas.cargar();
    _clasificador = Servicios.senas.clasificador;
    final error = await _ojo.abrir();
    if (!mounted) return;
    setState(() {
      _prendiendo = false;
      _error = error;
    });
    if (error != null) {
      nanaDice(context, error, siempre: true);
      return;
    }
    _sub = _ojo.manos.listen(_alVer);
  }

  // Qué seña es esta mano: primero lo que se le enseñó; si no, el pulgar
  // arriba o abajo cuentan como sí y no.
  String? _queEs(ManoVista m) =>
      _clasificador.clasificar(m.mano) ??
      (m.pulgarArriba
          ? senaSi
          : m.pulgarAbajo
          ? senaNo
          : null);

  void _alVer(ManoVista? m) {
    if (!mounted) return;
    final lista = _sostenida.ver(
      m == null ? null : _queEs(m),
      Servicios.reloj(),
    );
    setState(() => _hayMano = m != null);
    if (lista == null) return;

    final propuesta = _propuesta;
    if (propuesta != null) {
      // Está contestando la pregunta de NANA.
      if (lista == senaSi) _confirmar(propuesta);
      if (lista == senaNo) _otraVez();
      return;
    }
    // Sí y no sueltos no dicen nada: solo sirven para contestar.
    if (lista == senaSi || lista == senaNo) return;
    final frase = fraseDeSena(lista);
    if (frase == null) return;
    setState(() => _propuesta = frase);
    nanaDice(context, '¿Quisiste decir: $frase?', siempre: true);
  }

  void _confirmar(String frase) {
    Servicios.voz.callar();
    Navigator.pop(context, frase);
  }

  void _otraVez() {
    setState(() => _propuesta = null);
    nanaDice(context, 'Va, hazla otra vez.', siempre: true);
  }

  Future<void> _ensenar() async {
    await _apagar();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GrabarSenas()),
    );
  }

  // La cámara se apaga de inmediato, sin esperar nada antes.
  Future<void> _apagar() async {
    final sub = _sub;
    _sub = null;
    final apagada = _ojo.cerrar();
    await sub?.cancel();
    await apagada;
  }

  @override
  void dispose() {
    _apagar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viendo = _sostenida.viendo;
    final fraseViendo = viendo == null ? null : fraseDeSena(viendo);
    final sinSenas = _clasificador.vacio;
    return Scaffold(
      backgroundColor: ColoresNana.noche,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  // Mantener apretado: el equipo le enseña señas a NANA.
                  GestureDetector(
                    // Escondido a propósito: no es un botón para el lector.
                    excludeFromSemantics: true,
                    onLongPress: _ensenar,
                    child: _PildoraCamara(encendida: _error == null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ColoresNana.nocheClara,
                      border: Border.all(color: ColoresNana.lila, width: 2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: _error != null
                        ? _Mensaje(
                            icono: Icons.videocam_off_outlined,
                            titulo: _error!,
                            detalle: 'Puedes decírmelo tocando las frases.',
                          )
                        : _prendiendo
                        ? const _Mensaje(
                            icono: Icons.videocam_outlined,
                            titulo: 'Prendiendo la cámara…',
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: 300,
                                  height: 400,
                                  child: ExcludeSemantics(child: _ojo.vista()),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: _Estado(
                                  texto: _propuesta != null
                                      ? 'Pulgar arriba para sí, abajo para no'
                                      : fraseViendo != null &&
                                            viendo != senaSi &&
                                            viendo != senaNo
                                      ? 'Veo: $fraseViendo'
                                      : !_hayMano
                                      ? 'Pon tu mano frente a la cámara'
                                      : sinSenas
                                      ? 'Todavía no conozco señas. '
                                            'Pídele a tu familia que me enseñe.'
                                      : 'Haz tu seña y sostenla un momento',
                                  avance: _propuesta == null
                                      ? _sostenida.avance(Servicios.reloj())
                                      : null,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (_propuesta case final frase?) ...[
                const SizedBox(height: 16),
                _Pregunta(
                  frase: frase,
                  onSi: () => _confirmar(frase),
                  onNo: _otraVez,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.videocam_off, size: 32),
                  label: const Text('Apagar cámara'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ColoresNana.encendido,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PildoraCamara extends StatelessWidget {
  final bool encendida;
  const _PildoraCamara({required this.encendida});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: encendida ? ColoresNana.encendido : ColoresNana.nocheClara,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          encendida ? Icons.fiber_manual_record : Icons.videocam_off,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          encendida ? 'Cámara encendida' : 'Cámara apagada',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? detalle;
  const _Mensaje({required this.icono, required this.titulo, this.detalle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 80, color: Colors.white70),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, color: Colors.white),
        ),
        if (detalle != null) ...[
          const SizedBox(height: 6),
          Text(
            detalle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ],
      ],
    ),
  );
}

// La franja de abajo de la cámara: qué está viendo NANA y cuánto falta.
class _Estado extends StatelessWidget {
  final String texto;
  final double? avance;
  const _Estado({required this.texto, this.avance});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: ColoresNana.noche.withValues(alpha: 0.78),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (avance != null && avance! > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: ColoresNana.mascotaBordeClaro,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Pregunta extends StatelessWidget {
  final String frase;
  final VoidCallback onSi;
  final VoidCallback onNo;
  const _Pregunta({
    required this.frase,
    required this.onSi,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        const Text('¿Quisiste decir?', style: TextStyle(fontSize: 18)),
        Text(
          frase,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: ColoresNana.morado,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 64,
                child: FilledButton.icon(
                  onPressed: onSi,
                  icon: const Icon(Icons.thumb_up, size: 28),
                  label: const Text('Sí, eso'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.ok,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 64,
                child: OutlinedButton.icon(
                  onPressed: onNo,
                  icon: const Icon(Icons.thumb_down, size: 28),
                  label: const Text('No'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresNana.tinta,
                    side: const BorderSide(color: ColoresNana.gris, width: 2),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Enseñarle señas a NANA (para el equipo o la familia). Se elige la seña,
/// se hace frente a la cámara y se guardan 20 ejemplos: solo los puntos de
/// la mano, nunca imagen. Se abre manteniendo apretado "Cámara encendida".
class GrabarSenas extends StatefulWidget {
  const GrabarSenas({super.key});

  static const porTanda = 20;

  @override
  State<GrabarSenas> createState() => _GrabarSenasState();
}

class _GrabarSenasState extends State<GrabarSenas> {
  late final OjoSenas _ojo = Servicios.crearOjo();
  StreamSubscription<ManoVista?>? _sub;
  String? _error;
  bool _prendiendo = true;
  bool _hayMano = false;

  String _elegida = senasNana.first.id;
  // Cuántos faltan de la tanda que se está grabando; 0 = no está grabando.
  int _faltan = 0;
  int _cuadro = 0;

  @override
  void initState() {
    super.initState();
    _prender();
  }

  Future<void> _prender() async {
    await Servicios.senas.cargar();
    final error = await _ojo.abrir();
    if (!mounted) return;
    setState(() {
      _prendiendo = false;
      _error = error;
    });
    if (error == null) _sub = _ojo.manos.listen(_alVer);
  }

  void _alVer(ManoVista? m) {
    if (!mounted) return;
    if (_hayMano != (m != null)) setState(() => _hayMano = m != null);
    if (m == null || _faltan == 0) return;
    // Uno de cada tres cuadros, para que los ejemplos no salgan idénticos.
    if (_cuadro++ % 3 != 0) return;
    Servicios.senas.agregar(EjemploSena(_elegida, m.mano));
    setState(() => _faltan--);
    if (_faltan == 0) {
      mostrarAviso(context, 'Listo, ya me aprendí esa seña');
    }
  }

  Future<void> _borrar() async {
    await Servicios.senas.borrar(_elegida);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ojo.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cuantos = Servicios.senas.clasificador.cuantosPorSena;
    final frase = fraseDeSena(_elegida) ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enseñarle señas a NANA'),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: 'Compartir las señas grabadas',
            icon: const Icon(Icons.ios_share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: Servicios.senas.exportar(),
                subject: 'senas.json',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Elige una seña, hazla frente a la cámara y toca Grabar. '
              'Muévela un poquito mientras se graba. Solo se guardan los '
              'puntos de la mano, nunca la imagen.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in senasNana)
                  ChoiceChip(
                    selected: s.id == _elegida,
                    onSelected: _faltan > 0
                        ? null
                        : (_) => setState(() => _elegida = s.id),
                    label: Text(
                      '${s.frase} · ${cuantos[s.id] ?? 0}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 320,
                color: ColoresNana.nocheClara,
                child: _error != null
                    ? _Mensaje(
                        icono: Icons.videocam_off_outlined,
                        titulo: _error!,
                      )
                    : _prendiendo
                    ? const _Mensaje(
                        icono: Icons.videocam_outlined,
                        titulo: 'Prendiendo la cámara…',
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: 300,
                              height: 400,
                              child: ExcludeSemantics(child: _ojo.vista()),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: _Estado(
                              texto: _faltan > 0
                                  ? 'Grabando "$frase"… faltan $_faltan'
                                  : _hayMano
                                  ? 'Veo tu mano'
                                  : 'No veo ninguna mano',
                              avance: _faltan > 0
                                  ? 1 - _faltan / GrabarSenas.porTanda
                                  : null,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _error != null || _faltan > 0 || !_hayMano
                  ? null
                  : () => setState(() {
                      _cuadro = 0;
                      _faltan = GrabarSenas.porTanda;
                    }),
              icon: const Icon(Icons.fiber_manual_record, size: 28),
              label: Text('Grabar "$frase"'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: OutlinedButton.icon(
                onPressed: (cuantos[_elegida] ?? 0) == 0 || _faltan > 0
                    ? null
                    : _borrar,
                icon: const Icon(Icons.delete_outline, size: 28),
                label: const Text('Borrar lo grabado de esta seña'),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
