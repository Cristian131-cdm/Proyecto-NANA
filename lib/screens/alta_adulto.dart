import 'package:flutter/material.dart';

import '../core/medicion.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../widgets/formulario.dart';
import 'arranque.dart';
import 'codigo_vinculacion.dart';
import 'formulario_salud.dart';
import 'panel_cuidador.dart';
import 'unirme_con_codigo.dart';

// Después de crear su cuenta, el cuidador da de alta a quien va a cuidar.
class AltaAdulto extends StatefulWidget {
  const AltaAdulto({super.key});

  static const parentescos = [
    'mamá',
    'papá',
    'abuela',
    'abuelo',
    'tía',
    'tío',
    'otro',
  ];

  @override
  State<AltaAdulto> createState() => _AltaAdultoState();
}

class _AltaAdultoState extends State<AltaAdulto> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  String? _parentesco;
  int _paso = 1; // 1 quién es, 2 permiso para guardar, 3 ¿tiene celular?
  bool _acepto = false;
  bool _intento = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    super.dispose();
  }

  String get _quien => _nombre.text.trim();
  String get _numero => _telefono.text.replaceAll(' ', '');
  bool get _telefonoMal =>
      _numero.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(_numero);

  void _siguiente() {
    setState(() => _intento = true);
    if (_quien.isEmpty || _parentesco == null || _telefonoMal) return;
    setState(() => _paso = 2);
  }

  Future<void> _darDeAlta({required bool tieneCelular}) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final repo = Servicios.repo;
      final folio = await repo.altaAdulto(
        nombre: _quien,
        apellidos: _apellidos.text.trim(),
        parentesco: _parentesco!,
        tieneCelular: tieneCelular,
        telefono: _numero.isEmpty ? null : _numero,
      );
      final codigo = tieneCelular ? await repo.generarCodigo(folio) : null;
      Medicion.tarea('alta');
      if (!mounted) return;
      final nombre = _quien;
      // Primero su salud (opcional) y después el código o el aviso.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FormularioSalud(
            folio: folio,
            nombre: nombre,
            alTerminar: (ctx) => Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(
                builder: (_) => codigo == null
                    ? SinCelular(nombre: nombre)
                    : PantallaCodigo(codigo: codigo, nombreAdulto: nombre),
              ),
            ),
          ),
        ),
      );
    } on ErrorNana catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_paso) {
      1 => _pasoQuien(),
      2 => _pasoPermiso(),
      _ => _pasoCelular(),
    };
  }

  // Antes de guardar nada de la persona, el encargado sabe qué se guarda y
  // lo acepta. Sin esto no se da de alta.
  Widget _pasoPermiso() {
    return PantallaPaso(
      // Con llave propia cada paso abre desde arriba.
      key: const ValueKey('paso2'),
      barra: 'Paso 2 de 3',
      titulo: 'Antes de guardar sus datos',
      subtitulo: 'NANA guarda lo mínimo, con tu permiso.',
      children: [
        for (final (icono, texto) in avisosDeDatos(_quien))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: ColoresNana.morado, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texto, style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: _acepto,
          onChanged: (v) => setState(() => _acepto = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: ColoresNana.morado,
          title: Text(
            'Estoy de acuerdo y $_quien también lo sabe',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          texto: 'Continuar',
          onPressed: _acepto ? () => setState(() => _paso = 3) : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _paso = 1),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          child: const Text('Regresar'),
        ),
      ],
    );
  }

  Widget _pasoQuien() {
    final faltaNombre = _intento && _quien.isEmpty;
    final faltaParentesco = _intento && _parentesco == null;
    return PantallaPaso(
      // Con llave propia cada paso abre desde arriba.
      key: const ValueKey('paso1'),
      barra: 'Paso 1 de 3',
      titulo: '¿A quién vas a cuidar?',
      children: [
        CampoNana(
          controller: _nombre,
          etiqueta: 'Nombre',
          error: faltaNombre ? 'Escribe su nombre' : null,
          onChanged: (_) => setState(() {}),
        ),
        CampoNana(controller: _apellidos, etiqueta: 'Apellidos'),
        CampoNana(
          controller: _telefono,
          etiqueta: 'Su teléfono (opcional)',
          teclado: TextInputType.phone,
          error: _intento && _telefonoMal ? 'Escribe los 10 números' : null,
          onChanged: (_) => setState(() {}),
        ),
        const Text(
          '¿Qué es tuyo?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SelectorParentesco(
          valor: _parentesco,
          onCambio: (p) => setState(() => _parentesco = p),
        ),
        if (faltaParentesco) ...[
          const SizedBox(height: 12),
          const MensajeError('Elige qué es tuyo'),
        ],
        const SizedBox(height: 28),
        BotonPrincipal(texto: 'Siguiente', onPressed: _siguiente),
        const SizedBox(height: 8),
        // Si alguien de la familia ya la dio de alta, no hay que repetirlo.
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UnirmeConCodigo()),
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          child: const Text('¿Te invitaron? Usa tu código'),
        ),
      ],
    );
  }

  Widget _pasoCelular() {
    return PantallaPaso(
      // Con llave propia cada paso abre desde arriba.
      key: const ValueKey('paso3'),
      barra: 'Paso 3 de 3',
      titulo: '¿$_quien tiene celular propio?',
      subtitulo: 'Si tiene, te damos un código para que use NANA en su propio celular.',
      children: [
        if (_error != null) MensajeError(_error!),
        BotonPrincipal(
          texto: 'Sí, tiene celular',
          ocupado: _ocupado,
          onPressed: () => _darDeAlta(tieneCelular: true),
        ),
        const SizedBox(height: 16),
        BotonSecundario(
          texto: 'No tiene',
          onPressed: _ocupado ? null : () => _darDeAlta(tieneCelular: false),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _ocupado ? null : () => setState(() => _paso = 2),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          child: const Text('Regresar'),
        ),
      ],
    );
  }
}

// Lo que se le explica al encargado antes de guardar datos de la persona.
// El mismo texto sale en "Tus datos" (PantallaPrivacidad).
List<(IconData, String)> avisosDeDatos(String quien) => [
  (
    Icons.folder_outlined,
    'Se guardan sus medicinas y rutinas, cuándo las confirma, cómo dice '
        'sentirse y los datos de salud que tú escribas.',
  ),
  (
    Icons.group_outlined,
    'Solo los ven $quien y la familia que tú invites con un código.',
  ),
  (
    Icons.no_photography_outlined,
    'NANA nunca sube documentos. Si agregas la foto de una receta, se queda '
        'solo en tu celular.',
  ),
  (
    Icons.delete_outline,
    'Puedes borrar todos sus datos cuando quieras, desde "Familia y '
        'alertas".',
  ),
];

// Las opciones de "¿Qué es tuyo?", iguales al dar de alta y al unirse.
class SelectorParentesco extends StatelessWidget {
  final String? valor;
  final ValueChanged<String> onCambio;
  const SelectorParentesco({
    super.key,
    required this.valor,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in AltaAdulto.parentescos)
          ChoiceChip(
            label: Text(p, style: const TextStyle(fontSize: 20)),
            selected: valor == p,
            showCheckmark: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            selectedColor: ColoresNana.moradoClaro,
            onSelected: (_) => onCambio(p),
          ),
      ],
    );
  }
}

class SinCelular extends StatelessWidget {
  final String nombre;
  const SinCelular({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return PantallaPaso(
      titulo: 'Tú llevarás el día de $nombre',
      subtitulo:
          'Desde tu celular anotas sus medicinas y cómo va. '
          'Si después tiene celular, genera su código en Mi cuenta.',
      children: [
        BotonPrincipal(
          texto: 'Ir a mi panel',
          onPressed: () => entrarA(context, const PanelCuidador()),
        ),
      ],
    );
  }
}
