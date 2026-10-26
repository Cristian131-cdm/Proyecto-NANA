import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/formulario.dart';
import '../widgets/mascota_nana.dart';
import 'cuenta_cuidador.dart';
import 'entrar_con_codigo.dart';
import 'registro_adulto.dart';

// Primera pantalla para quien no tiene sesión en este celular.
class Bienvenida extends StatelessWidget {
  const Bienvenida({super.key});

  void _ir(BuildContext context, Widget pantalla) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => pantalla),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const MascotaNana(tamano: 140),
                const SizedBox(height: 20),
                const Text(
                  'NANA',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: ColoresNana.morado,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nunca Ausente, Nunca Abandonad@',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => _ir(context, const OpcionesAdulto()),
                  child: const Text('Soy adulto mayor'),
                ),
                const SizedBox(height: 16),
                BotonSecundario(
                  texto: 'Soy cuidador o familiar',
                  onPressed: () => _ir(context, const OpcionesCuidador()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OpcionesAdulto extends StatelessWidget {
  const OpcionesAdulto({super.key});

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      titulo: '¡Hola! ¿Cómo quieres entrar?',
      subtitulo: 'Si tu familia ya usa NANA, te dieron un código de 6 números.',
      children: [
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EntrarConCodigo()),
          ),
          child: const Text('Entrar con un código'),
        ),
        const SizedBox(height: 16),
        BotonSecundario(
          texto: 'Registrarme',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegistroAdulto()),
          ),
        ),
      ],
    );
  }
}

class OpcionesCuidador extends StatelessWidget {
  const OpcionesCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      titulo: 'Cuida a tu familiar con NANA',
      subtitulo: 'Crea tu cuenta y después das de alta a quien vas a cuidar.',
      children: [
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CuentaCuidador(crear: true)),
          ),
          child: const Text('Crear cuenta'),
        ),
        const SizedBox(height: 16),
        BotonSecundario(
          texto: 'Ya tengo cuenta',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CuentaCuidador(crear: false),
            ),
          ),
        ),
      ],
    );
  }
}
