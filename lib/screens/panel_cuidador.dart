import 'package:flutter/material.dart';

import '../core/avisos.dart';
import '../core/dia.dart';
import '../core/medicion.dart';
import '../core/permisos.dart';
import '../core/platica.dart';
import '../widgets/espera_oye_nana.dart';
import 'platica_nana.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/aviso.dart';
import '../widgets/esqueleto.dart';
import '../widgets/formulario.dart';
import 'alta_adulto.dart';
import 'arranque.dart';
import 'unirme_con_codigo.dart';
import 'pestana_mas.dart';
import 'pestana_inicio.dart';
import 'pestana_medicamentos.dart';

import 'pestana_semana.dart';

class PanelCuidador extends StatefulWidget {
  const PanelCuidador({super.key});

  @override
  State<PanelCuidador> createState() => _PanelCuidadorState();
}

class _PanelCuidadorState extends State<PanelCuidador> {
  int _pestana = 0;
  int _adulto = 0;
  final _adultos = Servicios.repo.adultosACargo();
  final _conTelefono = <String>{};
  // Avisan con una notificación del celular cuando llega una alerta nueva,
  // aunque NANA esté minimizada.
  final _vigilantes = <String, VigilanteAlertas>{};

  @override
  void dispose() {
    _paginas.dispose();
    for (final v in _vigilantes.values) {
      v.cancelar();
    }
    super.dispose();
  }

  Future<void> _cambiarAdulto(List<Adulto> lista) async {
    final elegido = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿A quién quieres ver?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < lista.length; i++)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: _Avatar(lista[i].nombre),
                  title: Text(
                    lista[i].nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    lista[i].parentesco ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: i == _adulto
                      ? const Icon(
                          Icons.check_circle,
                          color: ColoresNana.morado,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null) setState(() => _adulto = elegido);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Adulto>>(
      stream: _adultos,
      builder: (context, snap) {
        final lista = snap.data;
        if (lista == null) {
          return const Scaffold(body: SafeArea(child: EsqueletoCarga()));
        }
        if (lista.isEmpty) {
          return PantallaPaso(
            titulo: 'Todavía no cuidas a nadie',
            subtitulo: 'Da de alta a tu familiar para empezar.',
            children: [
              BotonPrincipal(
                texto: 'Dar de alta',
                onPressed: () => entrarA(context, const AltaAdulto()),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnirmeConCodigo()),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('Me invitaron, tengo un código'),
              ),
            ],
          );
        }
        // El estudio de uso corre solo si el encargado lo aceptó para alguien.
        Medicion.activa = lista.any((a) => a.estudio);
        Medicion.enviar = (lote) =>
            Servicios.repo.guardarUso(lote, rol: 'cuidador');
        // Que cada adulto tenga el teléfono de este cuidador en "Mi familia".
        for (final a in lista) {
          if (_conTelefono.add(a.folio)) {
            Servicios.repo.compartirMiTelefono(a.folio).ignore();
          }
          if (!_vigilantes.containsKey(a.folio)) {
            if (_vigilantes.isEmpty) Servicios.avisos.pedirPermiso().ignore();
            _vigilantes[a.folio] = VigilanteAlertas(
              avisos: Servicios.avisos,
              nombre: a.nombre,
              ahora: Servicios.reloj(),
            )..escuchar(Servicios.repo.alertasSinAtender(a.folio));
          }
        }
        final adulto = lista[_adulto.clamp(0, lista.length - 1)];
        return _panel(adulto, lista);
      },
    );
  }

  Widget _panel(Adulto adulto, List<Adulto> lista) {
    final nombre = adulto.nombre;
    final relacion = adulto.parentesco ?? '';
    final permisos = Permisos.de(adulto, Servicios.repo.uid, Servicios.reloj());

    return EsperaOyeNana(
      alOir: () => _preguntale(adulto),
      child: _pantallaPanel(adulto, lista, nombre, relacion, permisos),
    );
  }

  // «Pregúntale a NANA»: el encargado pregunta por el día o la semana y NANA
  // contesta con los mismos datos de las pestañas (sin IA, solo datos).
  void _preguntale(Adulto adulto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaticaNana(
          titulo: 'Pregúntale a NANA',
          saludo: '¿Qué quieres saber de ${adulto.nombre}?',
          responder: (oido) async => respuestaEncargado(
            oido,
            await cargarDatosEncargado(adulto.folio, adulto.nombre),
          ),
          sugerencias: const [
            '¿Cómo va hoy?',
            '¿Ya se tomó la pastilla?',
            '¿Cómo le fue esta semana?',
            '¿Hay alertas?',
          ],
        ),
      ),
    );
  }

  // Las 4 pestañas van en un PageView: se cambian tocando la barra de abajo
  // o deslizando con el dedo, y la barra sigue al dedo.
  final _paginas = PageController();

  void _irAPestana(int i) {
    setState(() => _pestana = i);
    if (!_paginas.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _paginas.jumpToPage(i);
    } else {
      _paginas.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _pantallaPanel(
    Adulto adulto,
    List<Adulto> lista,
    String nombre,
    String relacion,
    Permisos permisos,
  ) {
    final telefono = adulto.telefono;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // En pantallas bajitas con letra grande el encabezado cede
            // espacio (y se desliza) para que las pestañas sigan cabiendo.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    (MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).vertical -
                        80) *
                    0.45,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Cambiar de persona. Ahora: $nombre',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _cambiarAdulto(lista),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    AnilloDelDia(
                                      key: ValueKey('anillo-${adulto.folio}'),
                                      folio: adulto.folio,
                                      nombre: nombre,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            nombre,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: ColoresNana.morado,
                                            ),
                                          ),
                                          if (relacion.isNotEmpty)
                                            Text(
                                              relacion,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: ColoresNana.tintaSuave,
                                              ),
                                            ),
                                          if (permisos.rol !=
                                              RolCuidador.principal)
                                            Text(
                                              permisos.rol ==
                                                      RolCuidador.suplente
                                                  ? 'Eres suplente '
                                                        '(${vigenciaSuplente(adulto.suplente!)})'
                                                  : 'Eres familiar: ves y acompañas',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: ColoresNana.tintaSuave,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.expand_more,
                                      color: ColoresNana.morado,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (telefono != null) ...[
                          _BotonRedondo(
                            icono: Icons.call,
                            etiqueta: 'Llamar a $nombre',
                            fondo: ColoresNana.azul,
                            frente: Colors.white,
                            onTap: () => llamar(context, telefono),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _BotonRedondo(
                          icono: Icons.record_voice_over_outlined,
                          etiqueta: 'Pregúntale a NANA',
                          fondo: ColoresNana.moradoClaro,
                          frente: ColoresNana.morado,
                          onTap: () => _preguntale(adulto),
                        ),
                      ],
                    ),
                    const AvisoOyeNana(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: ColoresNana.moradoClaro),
            Expanded(
              child: PageView(
                controller: _paginas,
                onPageChanged: (i) => setState(() => _pestana = i),
                children: [
                  _Viva(
                    child: PestanaInicio(
                      key: ValueKey(adulto.folio),
                      adulto: adulto,
                    ),
                  ),
                  _Viva(
                    child: PestanaMedicamentos(
                      key: ValueKey(adulto.folio),
                      folio: adulto.folio,
                      puedeEditar: permisos.editarMedicinasYRutinas,
                    ),
                  ),
                  _Viva(
                    child: PestanaSemana(
                      key: ValueKey(adulto.folio),
                      adulto: nombre,
                      folio: adulto.folio,
                    ),
                  ),
                  _Viva(
                    child: PestanaMas(
                      key: ValueKey('mas-${adulto.folio}'),
                      adulto: adulto,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: ColoresNana.moradoClaro,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontSize: 14,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: s.contains(WidgetState.selected)
                  ? ColoresNana.morado
                  : ColoresNana.tintaSuave,
            ),
          ),
        ),
        child: NavigationBar(
          height: 80,
          selectedIndex: _pestana,
          onDestinationSelected: _irAPestana,
          destinations: [
            NavigationDestination(
              icon: ContadorAlertas(
                key: ValueKey('contador-${adulto.folio}'),
                folio: adulto.folio,
                child: const Icon(Icons.home_outlined),
              ),
              selectedIcon: ContadorAlertas(
                key: ValueKey('contador-sel-${adulto.folio}'),
                folio: adulto.folio,
                child: const Icon(Icons.home, color: ColoresNana.morado),
              ),
              label: 'Hoy',
            ),
            const NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication, color: ColoresNana.morado),
              label: 'Medicinas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: ColoresNana.morado),
              label: 'Semana',
            ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz, color: ColoresNana.morado),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }
}

// Botón redondo del encabezado (llamar, preguntarle a NANA).
class _BotonRedondo extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Color fondo;
  final Color frente;
  final VoidCallback onTap;

  const _BotonRedondo({
    required this.icono,
    required this.etiqueta,
    required this.fondo,
    required this.frente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    tooltip: etiqueta,
    icon: Icon(icono, size: 28),
    style: IconButton.styleFrom(
      backgroundColor: fondo,
      foregroundColor: frente,
      fixedSize: const Size(56, 56),
    ),
  );
}

// Mantiene viva una pestaña aunque no se vea, para no perder lo que se hizo
// en ella (como antes con IndexedStack).
class _Viva extends StatefulWidget {
  final Widget child;
  const _Viva({required this.child});

  @override
  State<_Viva> createState() => _VivaState();
}

class _VivaState extends State<_Viva> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _Avatar extends StatelessWidget {
  final String nombre;
  const _Avatar(this.nombre);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: ColoresNana.moradoClaro,
      child: Text(
        nombre.isEmpty ? '?' : nombre[0],
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ColoresNana.morado,
        ),
      ),
    );
  }
}

// Globito rojo con cuántas alertas hay (pide ayuda + medicinas vencidas),
// para verlo desde cualquier pestaña. El número va también en texto para
// TalkBack/VoiceOver, no solo en color.
class ContadorAlertas extends StatefulWidget {
  final String folio;
  final Widget child;
  const ContadorAlertas({super.key, required this.folio, required this.child});

  @override
  State<ContadorAlertas> createState() => _ContadorAlertasState();
}

class _ContadorAlertasState extends State<ContadorAlertas> {
  late final _alertas = Servicios.repo.alertasSinAtender(widget.folio);
  late final _meds = Servicios.repo.medicamentos(widget.folio);
  late final _hoy = Servicios.repo.registrosDeHoy(widget.folio);
  late final _reglas = Servicios.repo.reglasAlerta(widget.folio);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Alerta>>(
      stream: _alertas,
      builder: (context, alertas) => StreamBuilder<List<Medicamento>>(
        stream: _meds,
        builder: (context, meds) => StreamBuilder<List<Registro>>(
          stream: _hoy,
          builder: (context, hoy) => StreamBuilder<ReglasAlerta>(
            stream: _reglas,
            builder: (context, reglas) {
              final vencidas = (reglas.data ?? const ReglasAlerta()).medicina
                  ? sinConfirmar(
                      meds: meds.data ?? const [],
                      hoy: hoy.data ?? const [],
                      ahora: Servicios.reloj(),
                    ).length
                  : 0;
              final total = (alertas.data?.length ?? 0) + vencidas;
              return Semantics(
                label: total == 0
                    ? null
                    : total == 1
                    ? '1 alerta'
                    : '$total alertas',
                child: Badge(
                  isLabelVisible: total > 0,
                  label: Text('$total'),
                  backgroundColor: ColoresNana.alerta,
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// La inicial del adulto con un anillo que se llena según lo que lleva hoy
// (medicinas, comidas y actividad). Verde al completar.
class AnilloDelDia extends StatefulWidget {
  final String folio;
  final String nombre;
  const AnilloDelDia({super.key, required this.folio, required this.nombre});

  @override
  State<AnilloDelDia> createState() => _AnilloDelDiaState();
}

class _AnilloDelDiaState extends State<AnilloDelDia> {
  late final _meds = Servicios.repo.medicamentos(widget.folio);
  late final _rutinas = Servicios.repo.rutinas(widget.folio);
  late final _hoy = Servicios.repo.registrosDeHoy(widget.folio);

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Rutina>>(
        stream: _rutinas,
        builder: (context, rutinas) => StreamBuilder<List<Registro>>(
          stream: _hoy,
          builder: (context, hoy) {
            final ahora = Servicios.reloj();
            final dia = diaDelAdulto(
              meds: meds.data ?? const [],
              hoy: hoy.data ?? const [],
              otras: rutinasDeHoy(rutinas.data ?? const [], ahora),
              ahora: ahora,
            );
            final hechas = dia
                .where((a) => a.estado == EstadoActividad.hecha)
                .length;
            final total = dia.length;
            final completo = total > 0 && hechas == total;
            return Semantics(
              label: '${widget.nombre}: lleva $hechas de $total hoy',
              child: Tooltip(
                message: 'Hoy lleva $hechas de $total',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: total == 0 ? 0 : hechas / total),
                        duration: Duration(milliseconds: quieto ? 0 : 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: v,
                            strokeWidth: 4,
                            backgroundColor: ColoresNana.moradoClaro,
                            color: completo
                                ? ColoresNana.ok
                                : ColoresNana.morado,
                          ),
                        ),
                      ),
                      _Avatar(widget.nombre),
                      if (completo)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(
                            Icons.check_circle,
                            size: 18,
                            color: ColoresNana.ok,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
