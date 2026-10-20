import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../models/actividad.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';

class PestanaInicio extends StatefulWidget {
  final String adulto;
  const PestanaInicio({super.key, required this.adulto});

  @override
  State<PestanaInicio> createState() => _PestanaInicioState();
}

class _PestanaInicioState extends State<PestanaInicio> {
  bool _alertaResuelta = false;

  @override
  Widget build(BuildContext context) {
    final adulto = widget.adulto;
    final dia = DatosEjemplo.diaParaCuidador;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _alertaResuelta
              ? _EstadoBien(adulto: adulto)
              : _Alerta(
                  adulto: adulto,
                  onLlamar: () => avisoPendiente(context),
                  onResuelta: () => setState(() => _alertaResuelta = true),
                ),
        ),
        TituloSeccion('Hoy lleva ${_alertaResuelta ? 3 : 2} de 4'),
        Row(
          children: [
            Expanded(
              child: _Recuadro(
                icono: Icons.medication,
                titulo: 'Medicinas',
                valor: _alertaResuelta ? '2 / 2' : '1 / 2',
                color: _alertaResuelta ? ColoresNana.ok : ColoresNana.alerta,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _Recuadro(
                icono: Icons.restaurant,
                titulo: 'Comidas',
                valor: '1 / 3',
                color: ColoresNana.ok,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _Recuadro(
                icono: Icons.mood,
                titulo: 'Ánimo',
                valor: 'Bien',
                color: ColoresNana.ok,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _Recuadro(
                icono: Icons.directions_walk,
                titulo: 'Actividad',
                valor: '0 / 1',
                color: ColoresNana.tinta,
              ),
            ),
          ],
        ),
        const TituloSeccion('Su día'),
        for (var i = 0; i < dia.length; i++)
          _Evento(
            actividad: _alertaResuelta && i == 1
                ? dia[i].conEstado(EstadoActividad.hecha)
                : dia[i],
            ultimo: i == dia.length - 1,
          ),
        const SizedBox(height: 24),
        SizedBox(
          height: 60,
          child: FilledButton.icon(
            onPressed: () => avisoPendiente(context),
            icon: const Icon(Icons.call),
            label: Text('Llamar a $adulto'),
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

class _Alerta extends StatelessWidget {
  final String adulto;
  final VoidCallback onLlamar;
  final VoidCallback onResuelta;

  const _Alerta({
    required this.adulto,
    required this.onLlamar,
    required this.onResuelta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresNana.alertaClaro,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColoresNana.alerta, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: ColoresNana.alerta, size: 30),
              SizedBox(width: 8),
              Expanded(
                child: Text('Losartán de las 8:00 sin confirmar',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ColoresNana.alerta)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Ya pasaron los 30 minutos y $adulto no ha dicho que la tomó.',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onLlamar,
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresNana.alerta,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onResuelta,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColoresNana.alerta,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: ColoresNana.alerta),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Ya lo resolví'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoBien extends StatelessWidget {
  final String adulto;
  const _EstadoBien({required this.adulto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ColoresNana.okClaro,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: ColoresNana.ok, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Text('$adulto va bien hoy',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Recuadro extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _Recuadro({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColoresNana.moradoClaro, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: const Color(0xFF6B6485)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(titulo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF6B6485))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _Evento extends StatelessWidget {
  final Actividad actividad;
  final bool ultimo;

  const _Evento({required this.actividad, this.ultimo = false});

  @override
  Widget build(BuildContext context) {
    final estado = actividad.estado;
    final color = estado.color;
    final resaltar = estado == EstadoActividad.sinConfirmar;
    final apagado = estado == EstadoActividad.pendiente;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                actividad.hora,
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
                child: Icon(actividad.tipo.icono, color: color, size: 22),
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
                estado == EstadoActividad.hecha &&
                        actividad.tipo == TipoActividad.medicina
                    ? 'Losartán: ya lo revisaste'
                    : actividad.titulo,
                style: TextStyle(
                  fontSize: 18,
                  color: resaltar
                      ? ColoresNana.alerta
                      : apagado
                          ? const Color(0xFF8A82A3)
                          : ColoresNana.tinta,
                  fontWeight: resaltar ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
