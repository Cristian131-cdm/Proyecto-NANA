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
  return adultos.isEmpty
      ? const AltaAdulto(desdeRegistro: true)
      : const PanelCuidador();
}

// Al abrir la app: si quedó una sesión de quien cuida pero ya no tiene a nadie
// a su cargo (se salió del grupo, lo quitaron, o dejó el registro a medias),
// no tiene caso pedir la huella ni mandarlo al alta: se cierra esa sesión y
// se muestra la entrada de tres botones. Para seguir un registro a medias
// basta con «Ya tengo cuenta · Iniciar sesión».
Future<Widget> destinoAlArrancar() async {
  final destino = await destinoInicial();
  if (destino is! AltaAdulto) return destino;
  await Servicios.repo.cerrarSesion();
  Ajustes.huellaActivada.value = false;
  Ajustes.huellaOfrecida.value = false;
  return const Bienvenida();
}

Widget pantallaDelAdulto() => Ajustes.encuestaHecha.value
    ? const PanelAdulto()
    : const EncuestaApariencia();

// Cierra la sesión de este celular y vuelve a la entrada de tres botones.
// La huella era de esa cuenta: se apaga para que no se la pida a quien entre
// después. [aviso] se muestra al llegar («Ya no acompañas a Rosa»).
Future<void> salirDeNana(BuildContext context, {String? aviso}) async {
  await Servicios.repo.cerrarSesion();
  Ajustes.huellaActivada.value = false;
  Ajustes.huellaOfrecida.value = false;
  if (!context.mounted) return;
  entrarA(context, const Bienvenida());
  if (aviso != null) {
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(aviso)));
  }
}

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
      destino = await destinoAlArrancar();
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
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: MascotaNana(tamano: 140)));
}
