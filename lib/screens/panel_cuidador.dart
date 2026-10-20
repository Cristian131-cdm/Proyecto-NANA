import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../widgets/ajustes_texto.dart';
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

  Future<void> _cambiarAdulto() async {
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
              const Text('¿A quién quieres ver?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              for (var i = 0; i < DatosEjemplo.adultosACargo.length; i++)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: _Avatar(DatosEjemplo.adultosACargo[i].$1),
                  title: Text(DatosEjemplo.adultosACargo[i].$1,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text(DatosEjemplo.adultosACargo[i].$2,
                      style: const TextStyle(fontSize: 16)),
                  trailing: i == _adulto
                      ? const Icon(Icons.check_circle,
                          color: ColoresNana.morado)
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
    final (nombre, relacion) = DatosEjemplo.adultosACargo[_adulto];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _cambiarAdulto,
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
                      Text('$nombre · $relacion',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ColoresNana.morado)),
                      const Text('● Activa hace 12 min',
                          style:
                              TextStyle(fontSize: 13, color: ColoresNana.ok)),
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
              MaterialPageRoute(builder: (_) => FamiliaAlertas(adulto: nombre)),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // IndexedStack para no perder lo que se hizo al cambiar de pestaña
      body: IndexedStack(
        index: _pestana,
        children: [
          PestanaInicio(adulto: nombre),
          const PestanaMedicamentos(),
          const PestanaRutinas(),
          PestanaSemana(adulto: nombre),
          PestanaHistorial(adulto: nombre),
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
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: ColoresNana.morado),
                label: 'Inicio'),
            NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication, color: ColoresNana.morado),
                label: 'Medicinas'),
            NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note, color: ColoresNana.morado),
                label: 'Rutinas'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart, color: ColoresNana.morado),
                label: 'Semana'),
            NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder, color: ColoresNana.morado),
                label: 'Historial'),
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
      child: Text(nombre[0],
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColoresNana.morado)),
    );
  }
}
