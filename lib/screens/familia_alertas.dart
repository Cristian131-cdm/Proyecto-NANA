import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
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
  const FamiliaAlertas({super.key, required this.adulto});

  @override
  State<FamiliaAlertas> createState() => _FamiliaAlertasState();
}

class _FamiliaAlertasState extends State<FamiliaAlertas> {
  bool _medicina = true;
  bool _sinNoticias = true;
  int _horasSinNoticias = 12;

  void _verFamiliar(int i) {
    final f = DatosEjemplo.familia[i];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i == 0 ? '${f.$1} (tú)' : f.$1,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${f.$2[0].toUpperCase()}${f.$2.substring(1)} de ${widget.adulto}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(f.$3,
                style: const TextStyle(fontSize: 16, color: Color(0xFF6B6485))),
            if (i != 0) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: () => llamar(context, f.$4),
                  icon: const Icon(Icons.call),
                  label: Text('Llamar a ${f.$1}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.azul,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
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
    final texto = 'Te invito a cuidar a ${widget.adulto} en NANA. '
        'Abre la app y escribe este código: $codigo';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Código de invitación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(codigo,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: ColoresNana.morado)),
            const SizedBox(height: 12),
            const Text(
              'De prueba: el código se activará cuando haya cuentas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B6485)),
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
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: texto)),
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adulto = widget.adulto;
    return Scaffold(
      appBar: AppBar(title: const Text('Familia y alertas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          TituloSeccion('Quiénes cuidan a $adulto'),
          for (final (i, f) in DatosEjemplo.familia.indexed)
            TarjetaDato(
              icono: Icons.person,
              titulo: i == 0 ? 'Tú (${f.$1}) · ${f.$2}' : '${f.$1} · ${f.$2}',
              subtitulo: f.$3,
              onTap: () => _verFamiliar(i),
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
            encendida: _medicina,
            onCambio: (v) => setState(() => _medicina = v),
          ),
          _Regla(
            icono: Icons.schedule,
            titulo: 'Sin noticias',
            subtitulo:
                'Si pasan $_horasSinNoticias horas sin ningún registro',
            encendida: _sinNoticias,
            onCambio: (v) => setState(() => _sinNoticias = v),
            extra: _sinNoticias
                ? SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 6, label: Text('6 h')),
                      ButtonSegment(value: 12, label: Text('12 h')),
                      ButtonSegment(value: 24, label: Text('24 h')),
                    ],
                    selected: {_horasSinNoticias},
                    onSelectionChanged: (s) =>
                        setState(() => _horasSinNoticias = s.first),
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
      ),
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
    final color = encendida ? ColoresNana.alerta : const Color(0xFF8A82A3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ColoresNana.moradoClaro, width: 2),
        ),
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
                      Text(titulo,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(subtitulo,
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF6B6485))),
                    ],
                  ),
                ),
                Switch(
                  value: encendida,
                  onChanged: onCambio,
                  activeThumbColor: ColoresNana.morado,
                ),
              ],
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
