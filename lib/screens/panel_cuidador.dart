import 'package:flutter/material.dart';

import '../core/avisos.dart';
import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/demo.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../widgets/ajustes_texto.dart';
import '../widgets/aviso.dart';
import '../widgets/formulario.dart';
import 'alta_adulto.dart';
import 'arranque.dart';
import 'bienvenida.dart';
import 'codigo_vinculacion.dart';
import 'familia_alertas.dart';
import 'pestana_historial.dart';
import 'pestana_inicio.dart';
import 'pestana_medicamentos.dart';
import 'pestana_rutinas.dart';
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

  Future<void> _miCuenta(Adulto adulto) async {
    final opcion = await showModalBottomSheet<String>(
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
                'Mi cuenta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final (clave, icono, texto) in [
                (
                  'codigo',
                  Icons.phonelink_ring,
                  'Código para el celular de ${adulto.nombre}',
                ),
                ('alta', Icons.person_add_alt, 'Cuidar a otra persona'),
                (
                  'demo',
                  Icons.auto_awesome_outlined,
                  'Cargar datos de demostración',
                ),
                ('salir', Icons.logout, 'Cerrar sesión'),
              ])
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Icon(icono, color: ColoresNana.morado, size: 30),
                  title: Text(texto, style: const TextStyle(fontSize: 20)),
                  onTap: () => Navigator.pop(context, clave),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    switch (opcion) {
      case 'codigo':
        try {
          final codigo = await Servicios.repo.generarCodigo(adulto.folio);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PantallaCodigo(codigo: codigo, nombreAdulto: adulto.nombre),
            ),
          );
        } catch (e) {
          if (mounted) mostrarAviso(context, '$e');
        }
      case 'alta':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AltaAdulto()),
        );
      case 'demo':
        final si = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Cargar datos de demostración?'),
            content: Text(
              'Se agregan rutinas, una receta, dos citas y una semana de '
              'ejemplo para ${adulto.nombre}. No se borra nada de lo que ya '
              'tiene y el día de hoy no se toca.',
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, cargar'),
              ),
            ],
          ),
        );
        if (si != true) return;
        final n = await cargarDemo(
          Servicios.repo,
          adulto.folio,
          Servicios.reloj(),
        );
        if (mounted) {
          mostrarAviso(
            context,
            n == 0
                ? 'Ya tenía los datos de demostración'
                : 'Listo, datos cargados',
          );
        }
      case 'salir':
        await Servicios.repo.cerrarSesion();
        if (mounted) entrarA(context, const Bienvenida());
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Adulto>>(
      stream: _adultos,
      builder: (context, snap) {
        final lista = snap.data;
        if (lista == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
            ],
          );
        }
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _cambiarAdulto(lista),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(nombre),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        relacion.isEmpty ? nombre : '$nombre · $relacion',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ColoresNana.morado,
                        ),
                      ),
                      Text(
                        adulto.uidAdulto != null
                            ? '● Usa NANA en su celular'
                            : adulto.tieneCelular
                            ? '○ Falta conectar su celular'
                            : '○ Sin celular',
                        style: TextStyle(
                          fontSize: 13,
                          color: adulto.uidAdulto != null
                              ? ColoresNana.ok
                              : const Color(0xFF6B6485),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more, color: ColoresNana.morado),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields, size: 28),
            tooltip: 'Tamaño de letra',
            onPressed: () => mostrarAjustesTexto(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 28),
            tooltip: 'Familia y alertas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FamiliaAlertas(adulto: nombre, folio: adulto.folio),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 28),
            tooltip: 'Mi cuenta',
            onPressed: () => _miCuenta(adulto),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // IndexedStack para no perder lo que se hizo al cambiar de pestaña
      body: IndexedStack(
        index: _pestana,
        children: [
          PestanaInicio(key: ValueKey(adulto.folio), adulto: adulto),
          PestanaMedicamentos(key: ValueKey(adulto.folio), folio: adulto.folio),
          PestanaRutinas(key: ValueKey(adulto.folio), folio: adulto.folio),
          PestanaSemana(
            key: ValueKey(adulto.folio),
            adulto: nombre,
            folio: adulto.folio,
          ),
          PestanaHistorial(
            key: ValueKey(adulto.folio),
            adulto: nombre,
            folio: adulto.folio,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: ColoresNana.moradoClaro,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontSize: 13,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: s.contains(WidgetState.selected)
                  ? ColoresNana.morado
                  : const Color(0xFF6B6485),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
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
              label: 'Inicio',
            ),
            const NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication, color: ColoresNana.morado),
              label: 'Medicinas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note, color: ColoresNana.morado),
              label: 'Rutinas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: ColoresNana.morado),
              label: 'Semana',
            ),
            const NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder, color: ColoresNana.morado),
              label: 'Historial',
            ),
          ],
        ),
      ),
    );
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
