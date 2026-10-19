import 'package:flutter/material.dart';

import '../core/tema.dart';

import 'pestana_medicamentos.dart';
import '../widgets/ajustes_texto.dart';

class PanelCuidador extends StatelessWidget {
  const PanelCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel del cuidador'),
          actions: [
          IconButton(
            icon: const Icon(Icons.text_fields, size: 28),
            tooltip: 'Tamaño de letra',
            onPressed: () => mostrarAjustesTexto(context),
          ),
          const SizedBox(width: 8),
        ],
          bottom: const TabBar(
            labelColor: ColoresNana.morado,
            unselectedLabelColor: Color(0xFF8A82A3),
            indicatorColor: ColoresNana.morado,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Medicamentos'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _Resumen(),
            PestanaMedicamentos(),
            _Pendiente('Historial médico'),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: ColoresNana.okClaro,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: ColoresNana.ok, size: 44),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rosa va bien hoy',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('Activa hace 12 min', style: TextStyle(fontSize: 17)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Su día',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const _Evento(
          hora: '8:00',
          texto: 'Tomó el Losartán (50 mg)',
          icono: Icons.medication,
          color: ColoresNana.ok,
        ),
        const _Evento(
          hora: '9:10',
          texto: 'Dijo que se siente bien',
          icono: Icons.mood,
          color: ColoresNana.azul,
        ),
        const _Evento(
          hora: '15:00',
          texto: 'Falta registrar la comida de la tarde. Suele hacerlo a esta hora.',
          icono: Icons.restaurant,
          color: ColoresNana.alerta,
          ultimo: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 60,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.call),
            label: const Text('Llamar a Rosa'),
            style: FilledButton.styleFrom(
              backgroundColor: ColoresNana.azul,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'NANA solo registra, recuerda y alerta. No da recomendaciones médicas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B6485)),
        ),
      ],
    );
  }
}

class _Evento extends StatelessWidget {
  final String hora;
  final String texto;
  final IconData icono;
  final Color color;
  final bool ultimo;

  const _Evento({
    required this.hora,
    required this.texto,
    required this.icono,
    required this.color,
    this.ultimo = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                hora,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icono, color: color, size: 22),
              ),
              if (!ultimo)
                Expanded(
                  child: Container(width: 2, color: ColoresNana.moradoClaro),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 9, bottom: ultimo ? 0 : 24),
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 18,
                  color: ultimo ? ColoresNana.alerta : ColoresNana.tinta,
                  fontWeight: ultimo ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pendiente extends StatelessWidget {
  final String nombre;
  const _Pendiente(this.nombre);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$nombre: pendiente de construir',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
