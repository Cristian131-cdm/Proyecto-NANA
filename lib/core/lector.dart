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
// lee [texto]; al salir se calla.
class LeerAlAbrir extends StatefulWidget {
  final String Function() texto;
  final Widget child;
  const LeerAlAbrir({super.key, required this.texto, required this.child});

  @override
  State<LeerAlAbrir> createState() => _LeerAlAbrirState();
}

class _LeerAlAbrirState extends State<LeerAlAbrir> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // TalkBack ya lee la pantalla nueva solo; NANA solo habla si no está.
      if (!mounted || lectorDelSistemaActivo(context)) return;
      if (Ajustes.queMeHable.value) Servicios.voz.decir(widget.texto());
    });
  }

  @override
  void dispose() {
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
