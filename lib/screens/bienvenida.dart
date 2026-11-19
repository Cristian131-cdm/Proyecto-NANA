import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/formulario.dart';
import '../widgets/logo_nana.dart';
import 'cuenta_cuidador.dart';
import 'entrar_con_codigo.dart';
import 'unirme_con_codigo.dart';

// Primera pantalla para quien no tiene sesión en este celular: tres caminos
// del mismo tamaño (la persona mayor, quien cuida, quien fue invitado) y,
// abajo, entrar con una cuenta que ya existe.
class Bienvenida extends StatelessWidget {
  const Bienvenida({super.key});

  void _ir(BuildContext context, Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoNana(tamano: 120)),
                  const SizedBox(height: 10),
                  const Text(
                    'NANA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: ColoresNana.morado,
                    ),
                  ),
                  const Text(
                    'Nunca Ausente, Nunca Abandonad@',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17),
                  ),
                  const SizedBox(height: 22),
                  Semantics(
                    header: true,
                    child: const Text(
                      '¿Quién eres?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  BotonEntrada(
                    icono: Icons.person,
                    titulo: 'Soy la persona mayor',
                    detalle: 'Entro con el código de mi familia',
                    lleno: true,
                    onTap: () => _ir(context, const EntrarConCodigo()),
                  ),
                  const SizedBox(height: 12),
                  BotonEntrada(
                    icono: Icons.favorite_border,
                    titulo: 'Cuido a alguien',
                    detalle: 'Doy de alta a mi familiar en NANA',
                    onTap: () => _ir(context, const OpcionesCuidador()),
                  ),
                  const SizedBox(height: 12),
                  BotonEntrada(
                    icono: Icons.mail_outline,
                    titulo: 'Me invitaron',
                    detalle: 'Tengo un código de la familia',
                    onTap: () => _ir(context, const InvitadoConCodigo()),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        _ir(context, const CuentaCuidador(crear: false)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text(
                      'Ya tengo cuenta · Iniciar sesión',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Un camino de la entrada: ícono en círculo, título y una línea de para quién es.
class BotonEntrada extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool lleno;
  final VoidCallback onTap;

  const BotonEntrada({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.lleno = false,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = lleno ? ColoresNana.morado : Colors.white;
    final letra = lleno ? Colors.white : ColoresNana.morado;
    return Semantics(
      button: true,
      label: '$titulo. $detalle',
      excludeSemantics: true,
      child: Material(
        color: fondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: ColoresNana.morado, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: lleno
                        ? Colors.white
                        : ColoresNana.moradoClaro,
                    child: Icon(icono, color: ColoresNana.morado, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: letra,
                          ),
                        ),
                        Text(
                          detalle,
                          style: TextStyle(
                            fontSize: 16,
                            color: lleno
                                ? ColoresNana.moradoClaro
                                : ColoresNana.tinta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// «Cuido a alguien»: crear cuenta o entrar. El invitado tiene su propio
// botón en la entrada, así que aquí ya no va el enlace del código.
class OpcionesCuidador extends StatelessWidget {
  const OpcionesCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      barra: 'Cuido a alguien',
      titulo: 'Cuida a tu familiar con NANA',
      subtitulo: 'Crea tu cuenta y después das de alta a quien vas a cuidar.',
      children: [
        for (final (n, texto) in const [
          (1, 'Creas tu cuenta'),
          (2, 'Das de alta a tu familiar'),
          (3, 'Le das un código para su celular'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ColoresNana.moradoClaro,
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColoresNana.morado,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texto, style: const TextStyle(fontSize: 19)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CuentaCuidador(crear: true),
            ),
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
        const SizedBox(height: 20),
        const Text(
          '¿Alguien de tu familia ya la dio de alta? Regresa y toca '
          '«Me invitaron».',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: ColoresNana.tintaSuave),
        ),
      ],
    );
  }
}
