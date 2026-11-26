import 'package:flutter/material.dart';

import '../core/alarmas.dart' show pantallasOcupadas;
import '../core/lector.dart';
import '../core/platica.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../widgets/mascota_nana.dart';

// «Platicando con NANA»: se abre al decir «Oye NANA». NANA grande y animada
// (escucha, piensa, habla), con subtítulos de lo que dice para quien no
// escucha bien. La plática sigue sola: después de contestar vuelve a
// escuchar, hasta «gracias NANA», «adiós» o dos silencios seguidos.
// Las respuestas las da [responder]: hoy sin IA (core/platica.dart); el
// agente se conecta aquí mismo después.
class PlaticaNana extends StatefulWidget {
  final String titulo;
  final String saludo;
  final Responder responder;
  // Frases de ejemplo que también se pueden tocar en vez de decirlas.
  final List<String> sugerencias;
  // Lo que pide la respuesta: ayuda, familia o contarle algo a la familia.
  // Se llama después de cerrar la plática (salvo [AccionPlatica.frase]).
  final ValueChanged<RespuestaPlatica>? alAccion;

  const PlaticaNana({
    super.key,
    this.titulo = 'Platicando con NANA',
    required this.saludo,
    required this.responder,
    this.sugerencias = const [],
    this.alAccion,
  });

  @override
  State<PlaticaNana> createState() => _PlaticaNanaState();
}

enum _Fase { hablando, escuchando, pensando, quieta }

class _PlaticaNanaState extends State<PlaticaNana> {
  final _burbujas = <(bool, String)>[]; // (es NANA, texto)
  final _lista = ScrollController();
  _Fase _fase = _Fase.hablando;
  bool _cerrada = false;
  bool _ocupada = false; // un solo turno a la vez
  String? _tocada; // frase tocada que espera su turno
  String? _problema;

  @override
  void initState() {
    super.initState();
    pantallasOcupadas++;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _nanaDice(widget.saludo);
      _platicar();
    });
  }

  @override
  void dispose() {
    _cerrada = true;
    Servicios.voz.dejarDeEscuchar();
    Servicios.voz.callar();
    _lista.dispose();
    pantallasOcupadas--;
    super.dispose();
  }

  void _fijar(_Fase f) {
    if (mounted && !_cerrada) setState(() => _fase = f);
  }

  Future<void> _nanaDice(String texto) async {
    if (_cerrada || !mounted) return;
    setState(() {
      _burbujas.add((true, texto));
      _fase = _Fase.hablando;
    });
    _bajar();
    await nanaDice(context, texto, siempre: true);
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lista.hasClients) {
        _lista.animateTo(
          _lista.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Escucha y contesta en vueltas hasta que la persona termine o se calle.
  Future<void> _platicar() async {
    if (_ocupada || _cerrada) return;
    _ocupada = true;
    var silencios = 0;
    try {
      while (!_cerrada && mounted) {
        String? oido = _tocada;
        if (oido == null) {
          _fijar(_Fase.escuchando);
          oido = await Servicios.voz.escuchar(
            maximo: const Duration(seconds: 10),
            // Si dejó de hablar 1.5 s, ya terminó su frase.
            sirve: (t) => t.trim().isNotEmpty,
          );
        }
        if (_cerrada || !mounted) return;
        // Si tocó una frase mientras escuchaba, cuenta lo que tocó.
        oido = _tocada ?? oido;
        _tocada = null;
        if (oido == null) {
          final problema = Servicios.voz.problema;
          final silencio = problema == null || problema == 'No te escuché';
          if (!silencio) {
            // Sin permiso o sin reconocimiento: se dice y se espera un toque.
            setState(() => _problema = problema);
            await _nanaDice('$problema. Puedes tocar lo que me quieres decir.');
            _fijar(_Fase.quieta);
            return;
          }
          silencios++;
          if (silencios >= 2) {
            await _nanaDice('Aquí estoy cuando me necesites.');
            _cerrar();
            return;
          }
          await _nanaDice('No te escuché. ¿Me lo repites?');
          continue;
        }
        silencios = 0;
        final seguir = await _contestar(oido);
        if (!seguir) return;
      }
    } finally {
      _ocupada = false;
    }
  }

  // Devuelve false si la plática terminó.
  Future<bool> _contestar(String oido) async {
    setState(() {
      _problema = null;
      _burbujas.add((false, oido));
      _fase = _Fase.pensando;
    });
    _bajar();
    // Un momento de "pensando" para que se vea que NANA lo está armando.
    final r =
        (await Future.wait([
              widget.responder(oido),
              Future<void>.delayed(const Duration(milliseconds: 500)),
            ])).first
            as RespuestaPlatica;
    if (_cerrada || !mounted) return false;
    await _nanaDice(r.texto);
    switch (r.accion) {
      case AccionPlatica.ninguna:
        return true;
      case AccionPlatica.frase:
        widget.alAccion?.call(r);
        return true;
      case AccionPlatica.terminar ||
          AccionPlatica.ayuda ||
          AccionPlatica.familia ||
          AccionPlatica.llamar:
        _cerrar();
        if (r.accion != AccionPlatica.terminar) widget.alAccion?.call(r);
        return false;
    }
  }

  void _cerrar() {
    if (_cerrada || !mounted) return;
    _cerrada = true;
    Navigator.pop(context);
  }

  // Tocar una sugerencia cuenta como haberla dicho: se corta lo que estaba
  // escuchando y la plática la toma en su siguiente vuelta.
  void _tocar(String frase) {
    if (_cerrada) return;
    _tocada = frase;
    if (_ocupada) {
      Servicios.voz.dejarDeEscuchar();
    } else if (_fase == _Fase.quieta) {
      _platicar();
    }
  }

  String get _queHace => switch (_fase) {
    _Fase.escuchando => 'Te escucho…',
    _Fase.pensando => 'Déjame pensar…',
    _Fase.hablando => 'NANA te contesta',
    _Fase.quieta => 'Toca el micrófono para hablar',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresNana.moradoClaro,
      appBar: AppBar(
        backgroundColor: ColoresNana.moradoClaro,
        title: Text(widget.titulo),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Semantics(
              label: _queHace,
              liveRegion: true,
              child: MascotaNana(
                // Grande en un celular normal, más chica en la pantalla de
                // afuera del plegable para que quepan los botones.
                tamano: (MediaQuery.sizeOf(context).height * 0.2).clamp(
                  64.0,
                  150.0,
                ),
                estado: _fase == _Fase.pensando
                    ? EstadoNana.pensando
                    : EstadoNana.normal,
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                _queHace,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ColoresNana.morado,
                ),
              ),
            ),
            if (_problema != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _problema!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            const SizedBox(height: 8),
            // Subtítulos: todo lo que se dijo, lo más nuevo abajo.
            Expanded(
              child: ListView(
                controller: _lista,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  for (final (esNana, texto) in _burbujas)
                    _Burbuja(esNana: esNana, texto: texto),
                  if (widget.sugerencias.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Puedes decir o tocar:',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in widget.sugerencias)
                          ActionChip(
                            label: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: ColoresNana.morado,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: ColoresNana.lila,
                              width: 2,
                            ),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            onPressed: () => _tocar(s),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton.icon(
                        onPressed: _fase == _Fase.quieta
                            ? () {
                                setState(() => _problema = null);
                                _platicar();
                              }
                            : null,
                        icon: const Icon(Icons.mic, size: 30),
                        label: const Text('Hablar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: ColoresNana.azul,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 20,
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
                        onPressed: _cerrar,
                        icon: const Icon(Icons.stop_circle_outlined, size: 30),
                        label: const Text('Terminar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresNana.morado,
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: ColoresNana.morado,
                            width: 2,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final bool esNana;
  final String texto;
  const _Burbuja({required this.esNana, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esNana ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: esNana ? Colors.white : ColoresNana.morado,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(esNana ? 6 : 22),
            bottomRight: Radius.circular(esNana ? 22 : 6),
          ),
        ),
        child: Semantics(
          label: esNana ? 'NANA dice: $texto' : 'Tú dijiste: $texto',
          excludeSemantics: true,
          child: Text(
            texto,
            style: TextStyle(
              fontSize: esNana ? 22 : 20,
              fontWeight: esNana ? FontWeight.w600 : FontWeight.normal,
              color: esNana ? ColoresNana.tinta : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
