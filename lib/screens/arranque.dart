import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/biometria.dart';
import '../core/servicios.dart';
import '../models/usuario.dart';
import '../widgets/mascota_nana.dart';
import 'alta_adulto.dart';
import 'bienvenida.dart';
import 'candado.dart';
import 'encuesta_apariencia.dart';
import 'panel_adulto.dart';
import 'panel_cuidador.dart';
import 'recordatorio_alarma.dart';

// Decide a dónde va la persona según su sesión y su rol.
Future<Widget> destinoInicial() async {
  final repo = Servicios.repo;
  if (repo.uid == null) return const Bienvenida();
  final usuario = await repo.usuarioActual();
  if (usuario == null) return const Bienvenida();
  if (usuario.rol == Rol.adulto) return pantallaDelAdulto();
  final adultos = await repo.adultosACargo().first;
  return adultos.isEmpty ? const AltaAdulto() : const PanelCuidador();
}

Widget pantallaDelAdulto() => Ajustes.encuestaHecha.value
    ? const PanelAdulto()
    : const EncuestaApariencia();

// Entra a una pantalla principal borrando lo de atrás (registro, código...).
void entrarA(BuildContext context, Widget destino) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => destino),
    (_) => false,
  );
}

class Arranque extends StatefulWidget {
  const Arranque({super.key});

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    Widget destino;
    try {
      destino = await destinoInicial();
    } catch (_) {
      destino = const Bienvenida();
    }
    if (!mounted) return;
    final vigilante = VigilanteCandado.instancia;
    final pedir = hayQuePedirHuella(
      activada: Ajustes.huellaActivada.value && Servicios.repo.uid != null,
      enSegundoPlanDesde: null,
      ahora: Servicios.reloj(),
      vieneDeAlarma: vigilante.vieneDeAlarma,
    );
    if (pedir) {
      await Navigator.push(
        context,
        MaterialPageRoute<bool>(builder: (_) => const Candado()),
      );
    }
    if (!mounted) return;
    entrarA(context, destino);
    final alarma = Servicios.alarmas.abiertaDesde;
    if (alarma != null) await abrirDesdeAlarma(alarma);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: MascotaNana(tamano: 140)),
  );
}
