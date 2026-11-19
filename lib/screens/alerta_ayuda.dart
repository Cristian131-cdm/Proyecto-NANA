import 'dart:async';

import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../widgets/aviso.dart';

// «Rosa pidió ayuda» a pantalla completa, para cualquiera de la familia:
// llamarle, decir «Ya voy» o «Ya la atendí» (así la familia no se encima) y
// ver quién ya respondió.
class AlertaAyuda extends StatefulWidget {
  final Adulto adulto;
  final Alerta alerta;
  const AlertaAyuda({super.key, required this.adulto, required this.alerta});

  @override
  State<AlertaAyuda> createState() => _AlertaAyudaState();
}

class _AlertaAyudaState extends State<AlertaAyuda> {
  late Alerta _alerta = widget.alerta;
  bool _atendida = false;
  StreamSubscription<List<Alerta>>? _sub;

  @override
  void initState() {
    super.initState();
    // Cuando alguien la atiende deja de estar en «sin atender».
    _sub = Servicios.repo.alertasSinAtender(widget.adulto.folio).listen((l) {
      final viva = l.where((a) => a.id == _alerta.id);
      if (!mounted) return;
      setState(() {
        if (viva.isEmpty) {
          _atendida = true;
        } else {
          _alerta = viva.first;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _responder(String estado) async {
    await Servicios.repo.responderAlerta(
      widget.adulto.folio,
      _alerta.id,
      estado,
    );
    if (!mounted) return;
    if (estado == 'atendi') {
      Navigator.pop(context);
    } else {
      mostrarAviso(context, 'Le avisé a la familia que vas');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.adulto.nombre;
    final telefono = widget.adulto.telefono;
    final minutos = Servicios.reloj().difference(_alerta.fecha).inMinutes;
    final hace = minutos < 1
        ? 'Hace un momento'
        : minutos == 1
        ? 'Hace 1 minuto'
        : minutos < 60
        ? 'Hace $minutos minutos'
        : 'A las ${horaCorta(TimeOfDay.fromDateTime(_alerta.fecha))}';
    final yo = Servicios.repo.uid;

    return Scaffold(
      backgroundColor: ColoresNana.urgente,
      appBar: AppBar(
        backgroundColor: ColoresNana.urgente,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.notifications_active,
                  color: ColoresNana.urgente,
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                _atendida ? 'Ya atendieron a $nombre' : '$nombre pidió ayuda',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hace,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 22),
            if (telefono != null)
              _Boton(
                texto: 'Llamar a $nombre',
                icono: Icons.call,
                lleno: true,
                onPressed: () => llamar(context, telefono),
              ),
            if (!_atendida) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Boton(
                      texto: 'Ya voy',
                      onPressed: () => _responder('voy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Boton(
                      texto: 'Ya la atendí',
                      onPressed: () => _responder('atendi'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColoresNana.urgenteOscuro,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La familia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_alerta.respuestas.isEmpty)
                    const Text(
                      'Nadie ha respondido todavía.',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  for (final MapEntry(key: uid, value: r)
                      in _alerta.respuestas.entries)
                    // Nombre arriba y estado abajo: con letra grande no se
                    // empujan uno al otro.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            uid == yo
                                ? '${r.nombre.isEmpty ? 'Tú' : r.nombre} (tú)'
                                : r.nombre.isEmpty
                                ? 'Alguien de la familia'
                                : r.nombre,
                            style: const TextStyle(
                              fontSize: 19,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            r.atendio ? 'La atendió' : 'Va para allá',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Boton(
              texto: 'Llamar al 911',
              lleno: true,
              onPressed: () => llamar(context, '911'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final bool lleno;
  final VoidCallback onPressed;

  const _Boton({
    required this.texto,
    required this.onPressed,
    this.icono,
    this.lleno = false,
  });

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    const letra = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final hijo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[Icon(icono, size: 26), const SizedBox(width: 10)],
        Flexible(child: Text(texto, textAlign: TextAlign.center)),
      ],
    );
    return lleno
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 66),
              padding: const EdgeInsets.all(14),
              backgroundColor: Colors.white,
              foregroundColor: ColoresNana.urgente,
              shape: forma,
              textStyle: letra,
            ),
            child: hijo,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 62),
              padding: const EdgeInsets.all(12),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              shape: forma,
              textStyle: letra,
            ),
            child: hijo,
          );
  }
}
