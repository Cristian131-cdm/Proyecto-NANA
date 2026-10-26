import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/biometria.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../widgets/formulario.dart';

const motivoHuella = 'Para abrir NANA';

// Pantalla que tapa la app hasta que la persona pone su huella o su PIN.
// Nunca cierra la sesión: si falla, se vuelve a intentar.
class Candado extends StatefulWidget {
  const Candado({super.key});

  @override
  State<Candado> createState() => _CandadoState();
}

class _CandadoState extends State<Candado> {
  bool _probando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  Future<void> _desbloquear() async {
    if (_probando) return;
    setState(() => _probando = true);
    final ok = await Servicios.biometria.autenticar(motivoHuella);
    if (!mounted) return;
    setState(() => _probando = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: PantallaPaso(
        titulo: 'NANA está protegida',
        subtitulo: 'Usa tu huella, tu cara o el PIN de tu celular.',
        children: [
          const Icon(Icons.fingerprint, size: 96, color: ColoresNana.morado),
          const SizedBox(height: 24),
          BotonPrincipal(
            texto: 'Desbloquear',
            ocupado: _probando,
            onPressed: _desbloquear,
          ),
        ],
      ),
    );
  }
}

// Vigila cuándo la app se va a segundo plano y pone el candado al volver
// después de 30 minutos. Al abrir desde la alarma de una medicina no lo pone.
class VigilanteCandado with WidgetsBindingObserver {
  static final instancia = VigilanteCandado._();
  VigilanteCandado._();

  final navegador = GlobalKey<NavigatorState>();
  DateTime? _desde;
  bool _mostrando = false;
  bool vieneDeAlarma = false;

  void iniciar() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _desde ??= Servicios.reloj();
    } else if (state == AppLifecycleState.resumed) {
      final desde = _desde;
      _desde = null;
      if (desde == null) return;
      if (hayQuePedirHuella(
        activada: Ajustes.huellaActivada.value && Servicios.repo.uid != null,
        enSegundoPlanDesde: desde,
        ahora: Servicios.reloj(),
        vieneDeAlarma: vieneDeAlarma,
      )) {
        pedirDesbloqueo();
      }
      vieneDeAlarma = false;
    }
  }

  Future<void> pedirDesbloqueo() async {
    final nav = navegador.currentState;
    if (_mostrando || nav == null) return;
    _mostrando = true;
    await nav.push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const Candado(),
      ),
    );
    _mostrando = false;
  }
}
