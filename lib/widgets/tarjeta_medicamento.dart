import 'package:flutter/material.dart';
import '../core/tema.dart';

class TarjetaMedicamento extends StatelessWidget {
  final String nombre;
  final String dosis;
  final String hora;
  final bool tomada;
  final VoidCallback onTomar;

  const TarjetaMedicamento({
    super.key,
    required this.nombre,
    required this.dosis,
    required this.hora,
    required this.tomada,
    required this.onTomar,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tomada ? ColoresNana.ok : ColoresNana.morado,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tomada ? Icons.check_circle : Icons.schedule,
                  color: Colors.white, size: 32),
              const SizedBox(width: 10),
              Text(hora,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(nombre,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          Text(dosis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 22)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: tomada ? null : onTomar,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ColoresNana.morado,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              child: Text(tomada ? 'Registrado' : 'Ya la tomé'),
            ),
          ),
        ],
      ),
    );
  }
}