import 'package:flutter/material.dart';

class Medicamento {
  final String nombre;
  final String dosis;
  final TimeOfDay hora;
  final int ventanaMin; // minutos que NANA espera antes de alertar

  const Medicamento({
    required this.nombre,
    required this.dosis,
    required this.hora,
    required this.ventanaMin,
  });
}