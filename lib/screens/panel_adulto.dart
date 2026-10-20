import 'package:flutter/material.dart';
import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../models/actividad.dart';
import '../widgets/ajustes_texto.dart';
import '../widgets/aviso.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/hoja_frases.dart';
import '../widgets/mascota_nana.dart';
import 'nana_escucha.dart';

class PanelAdulto extends StatefulWidget {
  const PanelAdulto({super.key});

  @override
  State<PanelAdulto> createState() => _PanelAdultoState();
}

class _PanelAdultoState extends State<PanelAdulto> {
  final List<Actividad> dia = List.of(DatosEjemplo.diaRosa);
  int? animo;

  final frases = const [
    'Ya tomé mi medicina',
    'Ya comí',
    'Me siento mal',
    '¿Qué sigue hoy?',
  ];

  int get _hechas =>
      dia.where((a) => a.estado == EstadoActividad.hecha).length;

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días,';
    if (h < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  String _fecha() {
    const dias = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final n = DateTime.now();
    final texto = '${dias[n.weekday - 1]} ${n.day} de ${meses[n.month - 1]}';
    return '${texto[0].toUpperCase()}${texto.substring(1)}';
  }

  // Marca la actividad como hecha y pasa la siguiente pendiente a "ahora"
  void _marcarHecha(int i) {
    setState(() {
      dia[i] = dia[i].conEstado(EstadoActividad.hecha);
      final siguiente =
          dia.indexWhere((a) => a.estado == EstadoActividad.pendiente);
      if (siguiente != -1) {
        dia[siguiente] = dia[siguiente].conEstado(EstadoActividad.ahora);
      }
    });
    mostrarAviso(
      context,
      dia[i].tipo == TipoActividad.medicina
          ? 'Listo, anoté tu medicina'
          : 'Listo, lo anoté',
    );
  }

  void _decir(String frase) {
    if (frase == 'Necesito ayuda') {
      _confirmarAviso();
    } else {
      mostrarAviso(context, 'Anotado: $frase');
    }
  }

  Future<void> _masFrases() async {
    final f = await mostrarHojaFrases(context);
    if (f != null && mounted) _decir(f);
  }

  Future<void> _confirmarAviso() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Le aviso a tu familia?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Les mando un mensaje para que sepan que necesitas ayuda.',
                style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.alerta,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: const Text('Sí, avisar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('No, cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
    if (si == true && mounted) avisoPendiente(context);
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(texto,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sign_language, size: 30),
            tooltip: 'Lengua de señas',
            onPressed: () => avisoPendiente(context),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields, size: 30),
            tooltip: 'Tamaño de letra',
            onPressed: () => mostrarAjustesTexto(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ColoresNana.moradoClaro,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              children: [
                const MascotaNana(tamano: 76),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_saludo(), style: const TextStyle(fontSize: 22)),
                      const Text(DatosEjemplo.adulto,
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: ColoresNana.morado)),
                      Text(_fecha(), style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _titulo('Hoy llevas $_hechas de ${dia.length}'),
          for (var i = 0; i < dia.length; i++)
            _FilaDia(actividad: dia[i], onHecha: () => _marcarHecha(i)),
          _titulo('¿Cómo te sientes hoy?'),
          CaritasAnimo(
            seleccionado: animo,
            onSeleccion: (i) {
              setState(() => animo = i);
              mostrarAviso(context, 'Gracias por contarme');
            },
          ),
          _titulo('Frases rápidas'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in frases)
                BotonFrase(frase: f, onTap: () => _decir(f)),
              ActionChip(
                avatar: const Icon(Icons.add, color: ColoresNana.morado),
                label: const Text('Más frases',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ColoresNana.morado)),
                backgroundColor: Colors.white,
                side: const BorderSide(color: ColoresNana.lila, width: 2),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                onPressed: _masFrases,
              ),
            ],
          ),
          _titulo('Mi familia'),
          Row(
            children: [
              for (final f in DatosEjemplo.familia)
                Expanded(
                  child: _Contacto(
                    nombre: f.$1,
                    parentesco: f.$2,
                    onTap: () => avisoPendiente(context),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: ColoresNana.moradoClaro, width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _BotonGrande(
                  icono: Icons.mic,
                  texto: 'Hablar con NANA',
                  fondo: ColoresNana.azul,
                  frente: Colors.white,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NanaEscucha()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _BotonGrande(
                  icono: Icons.notifications_active,
                  texto: 'Necesito ayuda',
                  fondo: ColoresNana.alertaClaro,
                  frente: ColoresNana.alerta,
                  borde: ColoresNana.alerta,
                  onTap: _confirmarAviso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDia extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback onHecha;

  const _FilaDia({required this.actividad, required this.onHecha});

  @override
  Widget build(BuildContext context) {
    final estado = actividad.estado;
    final hecha = estado == EstadoActividad.hecha;
    final ahora = estado == EstadoActividad.ahora;
    final apagada = estado == EstadoActividad.pendiente;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ahora
              ? ColoresNana.morado
              : hecha
                  ? ColoresNana.okClaro
                  : ColoresNana.moradoClaro,
          width: ahora ? 3 : 2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: hecha
                ? ColoresNana.okClaro
                : ahora
                    ? ColoresNana.moradoClaro
                    : const Color(0xFFF2F0F7),
            child: Icon(
              hecha ? Icons.check : actividad.tipo.icono,
              size: 28,
              color: estado.color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${actividad.titulo} · ${actividad.hora}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: apagada ? const Color(0xFF6B6485) : ColoresNana.tinta,
                  ),
                ),
                Text(
                  hecha
                      ? 'Listo'
                      : ahora
                          ? 'Toca ahora · ${actividad.detalle}'
                          : actividad.detalle,
                  style: TextStyle(
                    fontSize: 16,
                    color: ahora ? ColoresNana.morado : const Color(0xFF6B6485),
                  ),
                ),
              ],
            ),
          ),
          if (ahora) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: onHecha,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.morado,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  textStyle: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: const Text('Ya'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Contacto extends StatelessWidget {
  final String nombre;
  final String parentesco;
  final VoidCallback onTap;

  const _Contacto({
    required this.nombre,
    required this.parentesco,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: ColoresNana.moradoClaro,
              child: Text(nombre[0],
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: ColoresNana.morado)),
            ),
            const SizedBox(height: 6),
            Text(nombre,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(parentesco, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            const Icon(Icons.call, color: ColoresNana.azul, size: 26),
          ],
        ),
      ),
    );
  }
}

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color fondo;
  final Color frente;
  final Color? borde;
  final VoidCallback onTap;

  const _BotonGrande({
    required this.icono,
    required this.texto,
    required this.fondo,
    required this.frente,
    required this.onTap,
    this.borde,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: borde != null
            ? BorderSide(color: borde!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          // Sin "alignment": con él, el Container se estira a toda la
          // altura disponible y la barra de abajo tapa la pantalla.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 34, color: frente),
              const SizedBox(height: 4),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: frente),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
