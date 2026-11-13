import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/tema.dart';

// El campo grande de 6 números. Lo usan el adulto (código de su celular) y
// el familiar (código de invitación).
class CampoCodigo extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const CampoCodigo({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      textAlign: TextAlign.center,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        letterSpacing: 12,
        color: ColoresNana.morado,
      ),
      decoration: InputDecoration(
        hintText: '······',
        semanticCounterText: 'Código de 6 números',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
