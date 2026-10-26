import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/registro.dart';
import '../widgets/aviso.dart';
import '../widgets/mascota_nana.dart';
import 'candado.dart';

// Se llama al tocar la alarma de una medicina: abre su recordatorio sin
// pedir la huella y, si dice que ya la tomó, lo anota.
Future<void> abrirDesdeAlarma(String idMedicamento) async {
  final vigilante = VigilanteCandado.instancia;
  vigilante.vieneDeAlarma = true;
  final repo = Servicios.repo;
  final yo = await repo.adultoPropio();
  if (yo == null) return;
  final meds = await repo.medicamentos(yo.folio).first;
  final m = meds.where((x) => x.id == idMedicamento).firstOrNull;
  final nav = vigilante.navegador.currentState;
  if (m == null || nav == null) return;
  final ok = await nav.push<bool>(
    MaterialPageRoute(
      builder: (_) => RecordatorioAlarma(
        actividad: Actividad(
          hora: horaCorta(m.hora),
          titulo: '${m.nombre} ${m.dosis}',
          detalle: 'Tu medicina',
          tipo: TipoActividad.medicina,
          estado: EstadoActividad.ahora,
          idMedicamento: m.id,
        ),
      ),
    ),
  );
  if (ok != true) return;
  await repo.registrar(
    yo.folio,
    Registro(
      tipo: TipoActividad.medicina,
      titulo: '${m.nombre} ${m.dosis}',
      idMedicamento: m.id,
      fecha: Servicios.reloj(),
      registradoPor: repo.uid ?? '',
    ),
  );
}

/// Recordatorio a pantalla completa, pensado para quien no ve bien.
/// Se abre desde la alarma de la medicina o desde su día. Falta que NANA lo
/// lea en voz alta y entienda "ya me la tomé" o "al rato" sin IA.
/// Regresa true si la persona confirmó.
class RecordatorioAlarma extends StatefulWidget {
  final Actividad actividad;
  const RecordatorioAlarma({super.key, required this.actividad});

  @override
  State<RecordatorioAlarma> createState() => _RecordatorioAlarmaState();
}

class _RecordatorioAlarmaState extends State<RecordatorioAlarma>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  void _alRato() {
    mostrarAviso(context, 'Está bien, sigue en tu lista de hoy');
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actividad;
    final esMedicina = a.tipo == TipoActividad.medicina;

    return Scaffold(
      backgroundColor: ColoresNana.morado,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  tooltip: 'Cerrar recordatorio',
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
                ),
                child: const MascotaNana(tamano: 120),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Son las ${a.hora}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                esMedicina ? 'Te toca tu ${a.titulo}' : 'Te toca: ${a.titulo}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                a.detalle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.graphic_eq, color: Colors.white, size: 26),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'NANA te está preguntando…',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 84,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_circle, size: 34),
                  label: Text(esMedicina ? 'Ya me la tomé' : 'Ya lo hice'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ColoresNana.morado,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 72,
                child: OutlinedButton.icon(
                  onPressed: _alRato,
                  icon: const Icon(Icons.schedule, size: 30),
                  label: const Text('Al rato'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
