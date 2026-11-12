import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'ajustes.dart';
import 'servicios.dart';

// "NANA me lee": para quien no ve bien, NANA dice en voz alta lo importante
// de cada pantalla. Si el celular ya tiene TalkBack o VoiceOver prendido, NANA
// no habla con su propia voz (se encimarían las dos): le pasa el texto al
// lector del sistema para que lo diga él.

bool lectorDelSistemaActivo(BuildContext context) =>
    MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

// siempre: hablar aunque "Que me hable" esté apagado (la alarma de la
// medicina, o cuando la persona tocó "Léeme").
Future<void> nanaDice(
  BuildContext context,
  String texto, {
  bool siempre = false,
}) async {
  if (texto.trim().isEmpty) return;
  if (lectorDelSistemaActivo(context)) {
    await SemanticsService.sendAnnouncement(
      View.of(context),
      texto,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
    return;
  }
  if (siempre || Ajustes.queMeHable.value) {
    await Servicios.voz.decir(texto);
  }
}

// Envuelve una pantalla: al abrirla, si "Que me hable" está prendido, NANA
// lee [texto]; al salir se calla. [listo]: false mientras los datos siguen
// cargando, para no leer una pantalla vacía; si en 3 s no llegan, lee lo
// que haya.
class LeerAlAbrir extends StatefulWidget {
  final String Function() texto;
  final bool listo;
  final Widget child;
  const LeerAlAbrir({
    super.key,
    required this.texto,
    required this.child,
    this.listo = true,
  });

  @override
  State<LeerAlAbrir> createState() => _LeerAlAbrirState();
}

class _LeerAlAbrirState extends State<LeerAlAbrir> {
  bool _leido = false;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.listo) {
        _leer();
      } else {
        _espera = Timer(const Duration(seconds: 3), _leer);
      }
    });
  }

  @override
  void didUpdateWidget(LeerAlAbrir old) {
    super.didUpdateWidget(old);
    if (widget.listo && !old.listo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leer());
    }
  }

  void _leer() {
    _espera?.cancel();
    if (_leido || !mounted) return;
    _leido = true;
    // TalkBack ya lee la pantalla nueva solo; NANA solo habla si no está.
    if (lectorDelSistemaActivo(context)) return;
    if (Ajustes.queMeHable.value) Servicios.voz.decir(widget.texto());
  }

  @override
  void dispose() {
    _espera?.cancel();
    Servicios.voz.callar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Botón de la barra: NANA lee esta pantalla aunque "Que me hable" esté
// apagado. Si ya está hablando, la calla.
class BotonLeeme extends StatelessWidget {
  final String Function() texto;
  final Color? color;
  const BotonLeeme({super.key, required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Servicios.voz.hablando,
      builder: (context, hablando, _) => IconButton(
        iconSize: 30,
        color: color,
        tooltip: hablando ? 'Callar a NANA' : 'Léeme esta pantalla',
        icon: Icon(
          hablando ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        ),
        onPressed: () => hablando
            ? Servicios.voz.callar()
            : nanaDice(context, texto(), siempre: true),
      ),
    );
  }
}
