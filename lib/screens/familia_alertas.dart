import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';

// Sin 0/O ni 1/I para que el código no se confunda al dictarlo.
String generarCodigo([Random? azar]) {
  const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = azar ?? Random.secure();
  return List.generate(6, (_) => letras[r.nextInt(letras.length)]).join();
}

class FamiliaAlertas extends StatefulWidget {
  final String adulto;
  final String folio;
  const FamiliaAlertas({super.key, required this.adulto, required this.folio});

  @override
  State<FamiliaAlertas> createState() => _FamiliaAlertasState();
}

class _FamiliaAlertasState extends State<FamiliaAlertas> {
  late final _familia = Servicios.repo.familiaDe(widget.folio);
  late final _reglas = Servicios.repo.reglasAlerta(widget.folio);

  void _guardar(ReglasAlerta r) =>
      Servicios.repo.guardarReglasAlerta(widget.folio, r);

  void _verFamiliar(Familiar f, bool soyYo) {
    final telefono = f.telefono;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              soyYo ? '${f.nombre} (tú)' : f.nombre,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuida a ${widget.adulto} · recibe todas las alertas',
              style: const TextStyle(
                fontSize: 16,
                color: ColoresNana.tintaSuave,
              ),
            ),
            if (telefono != null && telefono.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Teléfono: $telefono', style: const TextStyle(fontSize: 18)),
            ],
            if (!soyYo && telefono != null && telefono.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: () => llamar(context, telefono),
                  icon: const Icon(Icons.call),
                  label: Text('Llamar a ${f.nombre}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.azul,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _invitar() {
    final codigo = generarCodigo();
    final texto =
        'Te invito a cuidar a ${widget.adulto} en NANA. '
        'Abre la app y escribe este código: $codigo';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Código de invitación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              codigo,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: ColoresNana.morado,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'De prueba: el código se activará cuando haya cuentas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ColoresNana.tintaSuave),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              Navigator.pop(context);
              mostrarAviso(this.context, 'Código copiado');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(ShareParams(text: texto)),
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familia y alertas')),
      body: StreamBuilder<List<Familiar>>(
        stream: _familia,
        builder: (context, familia) => StreamBuilder<ReglasAlerta>(
          stream: _reglas,
          builder: (context, reglas) => _lista(
            familia.data ?? const [],
            reglas.data ?? const ReglasAlerta(),
          ),
        ),
      ),
    );
  }

  Widget _lista(List<Familiar> familia, ReglasAlerta reglas) {
    final adulto = widget.adulto;
    final yo = Servicios.repo.uid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        TituloSeccion('Quiénes cuidan a $adulto'),
        for (final f in familia)
          TarjetaDato(
            icono: Icons.person,
            titulo: f.uid == yo ? 'Tú (${f.nombre})' : f.nombre,
            subtitulo: (f.telefono ?? '').isEmpty
                ? 'Recibe todas las alertas'
                : 'Recibe todas las alertas · ${f.telefono}',
            onTap: () => _verFamiliar(f, f.uid == yo),
          ),
        BotonSecundario(
          icono: Icons.person_add_alt_1,
          texto: 'Invitar a alguien con código',
          onPressed: _invitar,
        ),
        const TituloSeccion('¿Cuándo te aviso?'),
        _Regla(
          icono: Icons.medication,
          titulo: 'Medicina sin confirmar',
          subtitulo: 'Según la ventana de cada medicina (15, 30 o 60 min)',
          encendida: reglas.medicina,
          onCambio: (v) => _guardar(reglas.copyWith(medicina: v)),
        ),
        _Regla(
          icono: Icons.schedule,
          titulo: 'Sin noticias',
          subtitulo:
              'Si pasan ${reglas.horasSinNoticias} horas sin ningún registro',
          encendida: reglas.sinNoticias,
          onCambio: (v) => _guardar(reglas.copyWith(sinNoticias: v)),
          extra: reglas.sinNoticias
              ? SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 6, label: Text('6 h')),
                    ButtonSegment(value: 12, label: Text('12 h')),
                    ButtonSegment(value: 24, label: Text('24 h')),
                  ],
                  selected: {reglas.horasSinNoticias},
                  onSelectionChanged: (s) =>
                      _guardar(reglas.copyWith(horasSinNoticias: s.first)),
                )
              : null,
        ),
        const _Regla(
          icono: Icons.notifications_active,
          titulo: 'Cuando pide ayuda',
          subtitulo: 'Siempre, al momento. Esta no se puede apagar.',
          encendida: true,
        ),
        const TituloSeccion('Privacidad'),
        TarjetaDato(
          icono: Icons.lock_outline,
          titulo: 'Qué datos se guardan',
          subtitulo: 'Y quién los puede ver',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PantallaPrivacidad()),
          ),
        ),
      ],
    );
  }
}

// Una regla de alerta con su interruptor. Sin onCambio queda fija (encendida).
class _Regla extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool encendida;
  final ValueChanged<bool>? onCambio;
  final Widget? extra;

  const _Regla({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.encendida,
    this.onCambio,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final color = encendida ? ColoresNana.morado : ColoresNana.tintaSuave;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SuperficieCuidador(
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 15,
                          color: ColoresNana.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: titulo,
                child: Switch(
                  value: encendida,
                  onChanged: onCambio,
                  activeThumbColor: ColoresNana.morado,
                ),
              ),
            ),
            if (extra != null) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: extra),
            ],
          ],
        ),
      ),
    );
  }
}

class PantallaPrivacidad extends StatelessWidget {
  const PantallaPrivacidad({super.key});

  static const _secciones = [
    (
      Icons.folder_outlined,
      'Qué guarda NANA',
      'Las rutinas y medicinas que registra la familia, cuándo se confirmaron, '
          'cómo se sintió (las caritas), las recetas que se capturan y las '
          'alertas que se mandaron.',
    ),
    (
      Icons.group_outlined,
      'Quién lo ve',
      'Solo las personas de la familia que se vincularon con código. '
          'Quien administra decide quién recibe alertas y quién solo ve el resumen.',
    ),
    (
      Icons.fingerprint,
      'Tu cara y tu huella',
      'Si entras con la cara o la huella, eso lo revisa tu teléfono. '
          'NANA nunca las recibe ni las guarda.',
    ),
    (
      Icons.block,
      'Lo que NANA no hace',
      'No da consejos médicos ni cambia dosis. No graba, no usa la cámara '
          'a escondidas y no rastrea dónde estás.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus datos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final s in _secciones)
            TarjetaDato(icono: s.$1, titulo: s.$2, subtitulo: s.$3),
        ],
      ),
    );
  }
}
