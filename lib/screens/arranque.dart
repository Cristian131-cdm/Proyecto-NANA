import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/servicios.dart';
import '../models/usuario.dart';
import '../widgets/mascota_nana.dart';
import 'alta_adulto.dart';
import 'bienvenida.dart';
import 'encuesta_apariencia.dart';
import 'panel_adulto.dart';
import 'panel_cuidador.dart';

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
    destinoInicial()
        .catchError((Object _) => const Bienvenida() as Widget)
        .then((destino) {
          if (mounted) entrarA(context, destino);
        });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: MascotaNana(tamano: 140)),
  );
}
