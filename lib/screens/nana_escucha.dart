import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/lector.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../core/voz.dart';
import '../widgets/hoja_frases.dart';
import '../widgets/mascota_nana.dart';
import 'senas.dart';

// Hablar con NANA. Al abrir, NANA saluda y escucha una frase corta; lo que
// oye se compara con [comandos] (sin IA). El agente de IA entrará después en
// esta misma pantalla. También se le puede decir algo tocando o con señas.
class NanaEscucha extends StatefulWidget {
  final String nombre;
  final ValueChanged<String> onFrase;
  // Lo que NANA contesta a "¿qué sigue?" (el resumen del día).
  final String Function()? queSigue;
  // "Llama a mi hija": abre Mi familia.
  final VoidCallback? onFamilia;

  const NanaEscucha({
    super.key,
    required this.nombre,
    required this.onFrase,
    this.queSigue,
    this.onFamilia,
  });

  // Lo que se entiende al hablar. Las preocupantes van primero, para que
  // "ya tomé mi medicina pero me siento mal" cuente como "me siento mal".
  // Con estas NANA deja de escuchar en cuanto las oye. Las demás ("ya comí")
  // esperan la frase completa por si sigue "…pero me siento mal".
  static const urgentes = {
    'Necesito ayuda',
    'Me siento mal',
    'familia',
    '¿Qué sigue hoy?',
  };

  static const comandos = <(String, List<String>)>[
    ('Necesito ayuda', ['ayuda', 'auxilio', 'emergencia', 'me cai']),
    (
      'Me siento mal',
      [
        'me siento mal',
        'me duele',
        'me siento enferma',
        'me siento enfermo',
        'estoy mareada',
        'estoy mareado',
      ],
    ),
    ('familia', ['llama', 'llamar', 'marca', 'marcale', 'hablale']),
    (
      '¿Qué sigue hoy?',
      ['que sigue', 'que me toca', 'que tengo hoy', 'que hay hoy'],
    ),
    (
      'Ya tomé mi medicina',
      [
        'ya me la tome',
        'ya tome mi medicina',
        'ya me tome',
        'ya tome la pastilla',
        'ya tome',
      ],
    ),
    ('Ya comí', ['ya comi', 'ya desayune', 'ya cene']),
  ];

  static const frases = [
    'Ya tomé mi medicina',
    'Ya comí',
    'Me siento mal',
    '¿Qué sigue hoy?',
  ];

  @override
  State<NanaEscucha> createState() => _NanaEscuchaState();
}

class _NanaEscuchaState extends State<NanaEscucha>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  bool _cerrada = false;
  String? _ultimoOido;
  String? _problema;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await nanaDice(
        context,
        'Te escucho, ${widget.nombre}. ¿Qué me quieres decir?',
        siempre: true,
      );
      _escuchar();
    });
  }

  @override
  void dispose() {
    _cerrada = true;
    Servicios.voz.dejarDeEscuchar();
    _pulso.dispose();
    super.dispose();
  }

  Future<void> _escuchar() async {
    if (_cerrada || !mounted) return;
    final oido = await Servicios.voz.escuchar(
      basta: (t) =>
          NanaEscucha.urgentes.contains(entender(t, NanaEscucha.comandos)),
    );
    if (_cerrada || !mounted) return;
    setState(() {
      _ultimoOido = oido;
      _problema = Servicios.voz.problema;
    });
    final c = entender(oido, NanaEscucha.comandos);
    // Si estaba en "Contestar tocando" y sí habló, el botón vuelve a ser
    // "Hablar": nadie tiene que buscar el ajuste.
    if (c != null && Ajustes.sinVoz.value) Ajustes.sinVoz.value = false;
    switch (c) {
      case null:
        await nanaDice(
          context,
          oido == null
              ? '${_problema ?? 'No te escuché'}. Toca el botón azul para hablar otra vez.'
              : 'No te entendí. Puedes tocar lo que me quieres decir.',
          siempre: true,
        );
      case 'familia' when widget.onFamilia != null:
        Navigator.pop(context);
        widget.onFamilia!();
      case '¿Qué sigue hoy?' when widget.queSigue != null:
        await nanaDice(context, widget.queSigue!(), siempre: true);
      case 'familia' || '¿Qué sigue hoy?':
        _decir(c == 'familia' ? 'Quiero hablar con mi familia' : c);
      default:
        _decir(c);
    }
  }

  void _decir(String frase) {
    if (_cerrada) return;
    _cerrada = true;
    nanaDice(context, 'Listo, se lo cuento a tu familia', siempre: true);
    Navigator.pop(context);
    widget.onFrase(frase);
  }

  Future<void> _masFrases() async {
    final f = await mostrarHojaFrases(context);
    if (f != null && mounted) _decir(f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresNana.moradoClaro,
      appBar: AppBar(
        backgroundColor: ColoresNana.moradoClaro,
        title: const Text('Hablando con NANA'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
                ),
                child: const MascotaNana(tamano: 130),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Te escucho, ${widget.nombre}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: ColoresNana.morado,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Habla con calma, o toca lo que me quieres decir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            _BotonMicrofono(onTap: _escuchar),
            if (_ultimoOido != null || _problema != null) ...[
              const SizedBox(height: 8),
              Text(
                _ultimoOido != null ? 'Escuché: "$_ultimoOido"' : _problema!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final f in NanaEscucha.frases)
                  BotonFrase(frase: f, onTap: () => _decir(f)),
                ActionChip(
                  avatar: const Icon(Icons.add, color: ColoresNana.morado),
                  label: const Text(
                    'Más frases',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ColoresNana.morado,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: ColoresNana.lila, width: 2),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  onPressed: _masFrases,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Forma(
                    icono: Icons.ondemand_video,
                    titulo: 'Ver en señas',
                    onTap: () => abrirVerEnSenas(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Forma(
                    icono: Icons.videocam_outlined,
                    titulo: 'Hablar con señas',
                    onTap: () => abrirHablarConSenas(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.stop_circle_outlined, size: 30),
              label: const Text('Terminar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Forma extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  const _Forma({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: ColoresNana.lila, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: ColoresNana.morado, size: 36),
              const SizedBox(height: 8),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Micrófono grande: muestra si NANA está escuchando y, al tocarlo, vuelve a
// escuchar (o deja de hacerlo).
class _BotonMicrofono extends StatelessWidget {
  final VoidCallback onTap;
  const _BotonMicrofono({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Servicios.voz.escuchando,
      builder: (context, escuchando, _) => Center(
        child: Semantics(
          button: true,
          label: escuchando
              ? 'NANA te está escuchando. Toca para que deje de escuchar'
              : 'Toca para hablar con NANA',
          excludeSemantics: true,
          child: SizedBox(
            height: 72,
            child: FilledButton.icon(
              onPressed: escuchando ? Servicios.voz.dejarDeEscuchar : onTap,
              icon: Icon(escuchando ? Icons.mic : Icons.mic_none, size: 34),
              label: Text(
                escuchando
                    ? 'Te escucho… (toca al terminar)'
                    : 'Toca para hablar',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: escuchando
                    ? ColoresNana.alerta
                    : ColoresNana.azul,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
