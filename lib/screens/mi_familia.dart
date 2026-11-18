import 'package:flutter/material.dart';

import '../core/lector.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/adulto.dart';
import '../widgets/aviso.dart';

// "Mi familia" del adulto: una tarjeta grande por familiar para llamarle.
class MiFamilia extends StatefulWidget {
  final String folio;
  const MiFamilia({super.key, required this.folio});

  @override
  State<MiFamilia> createState() => _MiFamiliaState();
}

class _MiFamiliaState extends State<MiFamilia> {
  late final _familia = Servicios.repo.familiaDe(widget.folio);
  String _texto = '';

  static String _leer(List<Familiar> lista) {
    if (lista.isEmpty) return 'Todavía no tienes familia conectada.';
    final nombres = lista.map((f) => f.nombre).join(', ');
    final conTelefono = lista.any((f) => f.telefono != null);
    return 'Tu familia: $nombres. '
        '${conTelefono ? 'Toca Llamar para hablarles.' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi familia'),
        actions: [
          BotonLeeme(texto: () => _texto, color: ColoresNana.morado),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Familiar>>(
        stream: _familia,
        builder: (context, snap) {
          final lista = snap.data;
          if (lista == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _texto = _leer(lista);
          if (lista.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no tienes familia conectada',
                style: TextStyle(fontSize: 24),
              ),
            );
          }
          return LeerAlAbrir(
            texto: () => _texto,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [for (final f in lista) _Tarjeta(f)],
            ),
          );
        },
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Familiar familiar;
  const _Tarjeta(this.familiar);

  @override
  Widget build(BuildContext context) {
    final f = familiar;
    final telefono = f.telefono;
    final inicial = f.nombre.isEmpty ? '?' : f.nombre[0].toUpperCase();
    final sinNumero = telefono == null || telefono.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ColoresNana.moradoClaro, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: ColoresNana.moradoClaro,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: ColoresNana.morado,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.nombre,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (sinNumero)
                      const Text(
                        'Sin número',
                        style: TextStyle(
                          fontSize: 19,
                          color: Color(0xFF6B6485),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!sinNumero) ...[
            const SizedBox(height: 16),
            // Dice solo «Llamar»; el lector dice a quién.
            Semantics(
              button: true,
              label: 'Llamar a ${f.nombre}',
              excludeSemantics: true,
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: FilledButton.icon(
                  onPressed: () => llamar(context, telefono),
                  icon: const Icon(Icons.call, size: 30),
                  label: const Text('Llamar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.ok,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
