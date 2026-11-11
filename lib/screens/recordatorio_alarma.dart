import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/dia.dart';
import '../core/lector.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../core/voz.dart';
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
        nombre: yo.nombre,
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
/// Se abre desde la alarma de la medicina o desde su día. NANA lo lee en voz
/// alta y entiende "ya me la tomé" o "al rato" con una lista fija, sin IA.
/// Regresa true si la persona confirmó.
class RecordatorioAlarma extends StatefulWidget {
  final Actividad actividad;
  final String nombre;
  const RecordatorioAlarma({
    super.key,
    required this.actividad,
    this.nombre = '',
  });

  @override
  State<RecordatorioAlarma> createState() => _RecordatorioAlarmaState();
}

class _RecordatorioAlarmaState extends State<RecordatorioAlarma>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  bool _cerrado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _conversar());
  }

  @override
  void dispose() {
    // Si se cerró con la X o con "atrás", NANA se calla. Si contestó, deja
    // que termine de decir lo que anotó.
    if (!_cerrado) Servicios.voz.callar();
    _cerrado = true;
    Servicios.voz.dejarDeEscuchar();
    _pulso.dispose();
    super.dispose();
  }

  bool get _esMedicina => widget.actividad.tipo == TipoActividad.medicina;

  String get _pregunta {
    final a = widget.actividad;
    final hola = widget.nombre.isEmpty ? '' : '${widget.nombre}, ';
    return _esMedicina
        ? '${hola}son las ${a.hora}. Te toca tu ${a.titulo}. ¿Ya te la tomaste?'
        : '${hola}son las ${a.hora}. Te toca: ${a.titulo}. ¿Ya lo hiciste?';
  }

  // NANA pregunta y escucha. Si no entiende, pregunta una vez más; si sigue
  // sin entender, se queda esperando a que toque un botón.
  Future<void> _conversar() async {
    for (var intento = 0; intento < 2; intento++) {
      if (_cerrado || !mounted) return;
      await nanaDice(
        context,
        intento == 0 ? _pregunta : 'No te entendí. Dime sí, o al rato.',
        siempre: true,
      );
      // Quien no habla contesta tocando: no se prende el micrófono.
      if (_cerrado || !mounted || Ajustes.sinVoz.value) return;
      // Con TalkBack el anuncio no avisa cuándo termina: se le da tiempo.
      if (lectorDelSistemaActivo(context)) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      if (_cerrado) return;
      final oido = await Servicios.voz.escuchar();
      if (_cerrado || !mounted) return;
      switch (entender(oido, respuestasRecordatorio)) {
        case RespuestaRecordatorio.si:
          _confirmar();
          return;
        case RespuestaRecordatorio.alRato:
          _alRato();
          return;
        case null:
          continue;
      }
    }
  }

  void _confirmar() {
    if (_cerrado) return;
    _cerrado = true;
    // NANA siempre dice en voz alta lo que anotó.
    final a = widget.actividad;
    nanaDice(
      context,
      _esMedicina ? 'Listo, anoté tu ${a.titulo}' : 'Listo, lo anoté',
      siempre: true,
    );
    Navigator.pop(context, true);
  }

  void _alRato() {
    if (_cerrado) return;
    _cerrado = true;
    final id = widget.actividad.idMedicamento;
    if (id != null) {
      Servicios.alarmas.posponer(id, _pregunta, const Duration(minutes: 10));
    }
    final texto = id != null
        ? 'Está bien, te pregunto otra vez en 10 minutos'
        : 'Está bien, sigue en tu lista de hoy';
    nanaDice(context, texto, siempre: true);
    mostrarAviso(context, texto);
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actividad;
    final esMedicina = a.tipo == TipoActividad.medicina;

    final sinVoz = Ajustes.sinVoz.value;
    // Para quien no ve: tocar cualquier parte fuera de los botones es "sí".
    final pantallaEsBoton = Ajustes.pantallaEsBoton.value;

    return Scaffold(
      backgroundColor: ColoresNana.morado,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: pantallaEsBoton ? _confirmar : null,
        child: SafeArea(
          // En pantallas bajitas (la de afuera del Flip, o con letra grande)
          // se puede deslizar en vez de cortarse.
          child: LayoutBuilder(
            builder: (context, caja) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: caja.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 32,
                            ),
                            tooltip: 'Cerrar recordatorio',
                          ),
                        ),
                        const Spacer(),
                        ScaleTransition(
                          scale: Tween(begin: 0.94, end: 1.06).animate(
                            CurvedAnimation(
                              parent: _pulso,
                              curve: Curves.easeInOut,
                            ),
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
                          esMedicina
                              ? 'Te toca tu ${a.titulo}'
                              : 'Te toca: ${a.titulo}',
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
                          child: ValueListenableBuilder<bool>(
                            valueListenable: Servicios.voz.escuchando,
                            builder: (context, escuchando, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sinVoz
                                      ? Icons.touch_app
                                      : escuchando
                                      ? Icons.mic
                                      : Icons.graphic_eq,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    pantallaEsBoton
                                        ? 'Toca la pantalla para decir que sí'
                                        : sinVoz
                                        ? 'Toca un botón para contestar'
                                        : escuchando
                                        ? 'Te escucho: di "ya me la tomé" o "al rato"'
                                        : 'NANA te está preguntando…',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 84,
                          child: FilledButton.icon(
                            onPressed: _confirmar,
                            icon: const Icon(Icons.check_circle, size: 34),
                            label: Text(
                              esMedicina ? 'Ya me la tomé' : 'Ya lo hice',
                            ),
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
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
