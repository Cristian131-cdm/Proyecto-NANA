import 'dart:async';

import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/datos_ejemplo.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../widgets/ajustes_texto.dart';
import '../widgets/aviso.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/hoja_frases.dart';
import '../widgets/mascota_nana.dart';
import 'nana_escucha.dart';
import 'recordatorio_alarma.dart';
import 'senas.dart';

class PanelAdulto extends StatefulWidget {
  const PanelAdulto({super.key});

  @override
  State<PanelAdulto> createState() => _PanelAdultoState();
}

class _PanelAdultoState extends State<PanelAdulto> {
  Adulto? _yo;
  bool _cargando = true;
  Stream<List<Medicamento>>? _meds;
  Stream<List<Registro>>? _hoy;
  StreamSubscription<List<Medicamento>>? _alarmas;

  final frases = const [
    'Ya tomé mi medicina',
    'Ya comí',
    'Me siento mal',
    '¿Qué sigue hoy?',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    Adulto? yo;
    try {
      yo = await Servicios.repo.adultoPropio();
    } catch (_) {
      // Sin internet la primera vez: se muestra vacío y Firestore reintenta.
    }
    if (!mounted) return;
    setState(() {
      _yo = yo;
      _cargando = false;
      _meds = Servicios.repo.medicamentos(_folio);
      _hoy = Servicios.repo.registrosDeHoy(_folio);
    });
    // Cada vez que la familia cambia las medicinas, se reprograman las alarmas.
    if (yo != null) {
      final nombre = yo.nombre;
      _alarmas = Servicios.repo
          .medicamentos(_folio)
          .listen((meds) => Servicios.alarmas.programar(nombre, meds));
    }
  }

  @override
  void dispose() {
    _alarmas?.cancel();
    super.dispose();
  }

  String get _folio => _yo?.folio ?? '';

  int _hechas(List<Actividad> dia) =>
      dia.where((a) => a.estado == EstadoActividad.hecha).length;

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días,';
    if (h < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  String _fecha() {
    const dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final n = DateTime.now();
    final texto = '${dias[n.weekday - 1]} ${n.day} de ${meses[n.month - 1]}';
    return '${texto[0].toUpperCase()}${texto.substring(1)}';
  }

  // Lo anota en Firestore; la lista se actualiza sola con lo que regresa.
  void _marcarHecha(Actividad a) {
    Servicios.repo.registrar(
      _folio,
      Registro(
        tipo: a.tipo,
        titulo: a.titulo,
        idMedicamento: a.idMedicamento,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
    );
    mostrarAviso(
      context,
      a.tipo == TipoActividad.medicina
          ? 'Listo, anoté tu medicina'
          : 'Listo, lo anoté',
    );
  }

  void _anotarAnimo(int i) {
    Servicios.repo.registrar(
      _folio,
      Registro(
        tipo: TipoActividad.animo,
        titulo: CaritasAnimo.etiquetas[i],
        valor: i,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
    );
    mostrarAviso(context, 'Gracias por contarme');
  }

  // Abre el recordatorio a pantalla completa (el que en la fase de función
  // suena como alarma y se contesta con la voz).
  Future<void> _abrirRecordatorio(Actividad a) async {
    final hecho = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecordatorioAlarma(actividad: a)),
    );
    if (hecho == true && mounted) _marcarHecha(a);
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
    if (_yo?.tieneFamilia != true) {
      mostrarAviso(context, 'Todavía no tienes familia conectada');
      return;
    }
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          '¿Le aviso a tu familia?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Les mando un mensaje para que sepan que necesitas ayuda.',
              style: TextStyle(fontSize: 20),
            ),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
    if (si != true || !mounted) return;
    final llego = await Servicios.repo.pedirAyuda(_folio);
    if (!mounted) return;
    mostrarAviso(
      context,
      llego
          ? 'Listo, ya le avisé a tu familia'
          : 'No hay internet. Lo mando en cuanto haya',
    );
  }

  Widget _titulo(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icono, color: ColoresNana.morado, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );

  // Escucha medicinas y registros de hoy y arma el día con ellos.
  Widget _conDia(Widget Function(List<Actividad> dia, int? animo) hijo) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Registro>>(
        stream: _hoy,
        builder: (context, regs) {
          final hoy = regs.data ?? const <Registro>[];
          final animos = hoy.where((r) => r.tipo == TipoActividad.animo);
          return hijo(
            diaDelAdulto(meds: meds.data ?? const [], hoy: hoy),
            animos.isEmpty ? null : animos.last.valor,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi día'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => mostrarAjustesTexto(context),
              icon: const Icon(Icons.accessibility_new, size: 26),
              label: const Text('Aa'),
              style: FilledButton.styleFrom(
                backgroundColor: ColoresNana.moradoClaro,
                foregroundColor: ColoresNana.morado,
                minimumSize: const Size(0, 48),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _conDia(
        (dia, animo) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ColoresNana.moradoClaro,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MascotaNana(tamano: 76),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _saludo(),
                              style: const TextStyle(fontSize: 22),
                            ),
                            Text(
                              _yo?.nombre ?? '',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: ColoresNana.morado,
                              ),
                            ),
                            Text(
                              _fecha(),
                              style: const TextStyle(fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hoy llevas ${_hechas(dia)} de ${dia.length}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: dia.isEmpty ? 0 : _hechas(dia) / dia.length,
                      ),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 14,
                        backgroundColor: Colors.white,
                        color: ColoresNana.ok,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _titulo(Icons.today, 'Lo de hoy'),
            for (var i = 0; i < dia.length; i++)
              _FilaDia(
                actividad: dia[i],
                onHecha: () => _marcarHecha(dia[i]),
                onAbrir: () => _abrirRecordatorio(dia[i]),
              ),
            _titulo(Icons.mood, '¿Cómo te sientes hoy?'),
            CaritasAnimo(seleccionado: animo, onSeleccion: _anotarAnimo),
            _titulo(Icons.chat_bubble_outline, 'Frases rápidas'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f in frases)
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
            _titulo(Icons.sign_language, 'Otras formas de hablar con NANA'),
            Row(
              children: [
                Expanded(
                  child: _TarjetaForma(
                    icono: Icons.ondemand_video,
                    titulo: 'Ver en señas',
                    detalle: 'NANA te habla en señas',
                    onTap: () => abrirVerEnSenas(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TarjetaForma(
                    icono: Icons.videocam_outlined,
                    titulo: 'Hablar con señas',
                    detalle: 'Usa la cámara, solo si tú quieres',
                    onTap: () => abrirHablarConSenas(context),
                  ),
                ),
              ],
            ),
            _titulo(Icons.family_restroom, 'Mi familia'),
            Row(
              children: [
                for (final f in DatosEjemplo.familia)
                  Expanded(
                    child: _Contacto(
                      nombre: f.$1,
                      parentesco: f.$2,
                      onTap: () => llamar(context, f.$4),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
  final VoidCallback onAbrir;

  const _FilaDia({
    required this.actividad,
    required this.onHecha,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final estado = actividad.estado;
    final hecha = estado == EstadoActividad.hecha;
    final ahora = estado == EstadoActividad.ahora;
    final apagada = estado == EstadoActividad.pendiente;
    final queEs = hecha
        ? 'listo'
        : ahora
        ? 'toca ahora'
        : 'más tarde';

    final fila = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
                    color: apagada
                        ? const Color(0xFF6B6485)
                        : ColoresNana.tinta,
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
              child: Semantics(
                button: true,
                label: 'Marcar ${actividad.titulo} como hecho',
                excludeSemantics: true,
                child: FilledButton(
                  onPressed: onHecha,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresNana.morado,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Ya'),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      label: '${actividad.titulo}, ${actividad.hora}, $queEs',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        // Tocar lo que toca ahora abre el recordatorio a pantalla completa.
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: ahora ? onAbrir : null,
            child: fila,
          ),
        ),
      ),
    );
  }
}

class _TarjetaForma extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _TarjetaForma({
    required this.icono,
    required this.titulo,
    required this.detalle,
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
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: ColoresNana.moradoClaro,
                child: Icon(icono, color: ColoresNana.morado, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                detalle,
                style: const TextStyle(fontSize: 15, color: Color(0xFF6B6485)),
              ),
            ],
          ),
        ),
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
    return Semantics(
      button: true,
      label: 'Llamar a $nombre, $parentesco',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: ColoresNana.moradoClaro,
                child: Text(
                  nombre[0],
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: ColoresNana.morado,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nombre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(parentesco, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              const Icon(Icons.call, color: ColoresNana.azul, size: 26),
            ],
          ),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: frente,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
