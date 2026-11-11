import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/dia.dart';
import '../core/frases.dart';
import '../core/lector.dart';
import '../core/perfil_accesibilidad.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/registro.dart';
import '../widgets/ajustes_texto.dart';
import '../widgets/aviso.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/esqueleto.dart';
import '../widgets/festejo.dart';
import '../widgets/mascota_nana.dart';
import '../widgets/tarjeta_ahora.dart';
import 'arranque.dart';
import 'bienvenida.dart';
import 'mi_dia.dart';
import 'mi_familia.dart';
import 'nana_escucha.dart';
import 'recordatorio_alarma.dart';
import 'tablero_frases.dart';
import '../widgets/icono_nana.dart';

// Inicio del adulto: una sola cosa a la vez (la tarjeta) y tres botones fijos.
// La lista completa del día está en "Ver todo mi día" (mi_dia.dart).
class PanelAdulto extends StatefulWidget {
  const PanelAdulto({super.key});

  @override
  State<PanelAdulto> createState() => _PanelAdultoState();
}

class _PanelAdultoState extends State<PanelAdulto> {
  Adulto? _yo;
  bool _cargando = true;
  StreamSubscription? _alarmas;
  StreamSubscription? _salud;

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
    });
    // Cada vez que la familia cambia las medicinas, se reprograman las alarmas.
    if (yo != null) {
      final nombre = yo.nombre;
      _alarmas = Servicios.repo
          .medicamentos(_folio)
          .listen((meds) => Servicios.alarmas.programar(nombre, meds));
      // Si la familia anota una discapacidad, el celular se adapta solo.
      _salud = Servicios.repo
          .salud(_folio)
          .listen((s) => aplicarPerfil(s.discapacidades));
    }
  }

  @override
  void dispose() {
    _alarmas?.cancel();
    _salud?.cancel();
    super.dispose();
  }

  String get _folio => _yo?.folio ?? '';

  // Lo último que se mostró en el inicio, para que NANA lo lea.
  String _textoInicio = '';

  int _hechas(List<Actividad> dia) =>
      dia.where((a) => a.estado == EstadoActividad.hecha).length;

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  // Lo anota en Firestore; la tarjeta se actualiza sola con lo que regresa.
  // Festejo corto y luego el aviso con "Deshacer" por si fue sin querer.
  Future<void> _marcarHecha(Actividad a) async {
    final folio = _folio;
    final id = await Servicios.repo.registrar(
      folio,
      Registro(
        tipo: a.tipo,
        titulo: a.titulo,
        idMedicamento: a.idMedicamento,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
    );
    if (!mounted) return;
    await mostrarFestejo(
      context,
      a.tipo == TipoActividad.medicina
          ? '¡Muy bien!\nAnoté tu medicina'
          : '¡Listo!',
    );
    if (!mounted) return;
    mostrarAviso(
      context,
      a.tipo == TipoActividad.medicina
          ? 'Listo, anoté tu medicina'
          : 'Listo, lo anoté',
      onDeshacer: () {
        Servicios.repo.borrarRegistro(folio, id);
        mostrarAviso(context, 'Lo quité');
      },
    );
  }

  Future<void> _anotarAnimo(int i) async {
    final folio = _folio;
    final id = await Servicios.repo.registrar(
      _folio,
      Registro(
        tipo: TipoActividad.animo,
        titulo: CaritasAnimo.etiquetas[i],
        valor: i,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
    );
    if (!mounted) return;
    mostrarAviso(
      context,
      'Gracias por contarme',
      onDeshacer: () => Servicios.repo.borrarRegistro(folio, id),
    );
  }

  // Abre el recordatorio a pantalla completa (el que en la fase de función
  // suena como alarma y se contesta con la voz).
  Future<void> _abrirRecordatorio(Actividad a) async {
    final hecho = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordatorioAlarma(actividad: a, nombre: _yo?.nombre ?? ''),
      ),
    );
    if (hecho == true && mounted) _marcarHecha(a);
  }

  // Lo que el adulto dice con las frases le llega a su familia: se anota en
  // su día y, si es algo preocupante, también como alerta. "Ya comí" marca la
  // comida y "Me siento bien" cuenta como su ánimo (ver core/frases.dart).
  void _decir(String frase) {
    if (frase == 'Necesito ayuda') {
      _confirmarAviso();
      return;
    }
    final comida = comidaDeFrase(frase);
    final animo = animoDeFrase(frase);
    Servicios.repo.registrar(
      _folio,
      Registro(
        tipo: comida != null
            ? TipoActividad.comida
            : animo != null
            ? TipoActividad.animo
            : TipoActividad.mensaje,
        titulo:
            comida ?? (animo != null ? CaritasAnimo.etiquetas[animo] : frase),
        valor: animo,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
    );
    final avisar = esPreocupante(frase) && _yo?.tieneFamilia == true;
    if (avisar) Servicios.repo.avisarFrase(_folio, frase);
    mostrarAviso(
      context,
      avisar ? 'Le avisé a tu familia' : 'Listo, se lo cuento a tu familia',
    );
  }

  Widget _nanaEscucha() => NanaEscucha(
    nombre: _yo?.nombre ?? '',
    onFrase: _decir,
    queSigue: () => _textoInicio,
    onFamilia: () => _ir(MiFamilia(folio: _folio)),
  );

  void _ir(Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

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

  // Escondido en "Aa" y con confirmación, para que no se salga sin querer.
  Future<void> _cerrarSesion() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          '¿Salir de NANA en este celular?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ya no te llegarán tus recordatorios aquí. Para volver a entrar '
              'necesitas un código nuevo de tu familia.',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNana.morado,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('No, quedarme'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('Sí, salir'),
              ),
            ),
          ],
        ),
      ),
    );
    if (si != true || !mounted) return;
    _alarmas?.cancel();
    _salud?.cancel();
    // Sin sesión no hay medicinas: se quitan las alarmas de este celular.
    await Servicios.alarmas.programar(_yo?.nombre ?? '', const []);
    await Servicios.repo.cerrarSesion();
    if (mounted) entrarA(context, const Bienvenida());
  }

  Widget _inicio(List<Actividad> dia, int? animo) {
    final (que, actividad) = queToca(
      dia: dia,
      animoHoy: animo,
      ahora: Servicios.reloj(),
    );
    final estado = estadoNana(dia: dia, que: que, ahora: Servicios.reloj());
    final quieto = MediaQuery.disableAnimationsOf(context);
    final suave = Duration(milliseconds: quieto ? 0 : 350);
    _textoInicio = textoDelDia(
      saludo: '${_saludo()}, ${_yo?.nombre ?? ''}',
      dia: dia,
      animoHoy: animo,
      ahora: Servicios.reloj(),
    );
    return LeerAlAbrir(
      texto: () => _textoInicio,
      child: _listaInicio(dia, animo, que, actividad, estado, suave),
    );
  }

  Widget _listaInicio(
    List<Actividad> dia,
    int? animo,
    QueToca que,
    Actividad? actividad,
    EstadoNana estado,
    Duration suave,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            // La cara de NANA cambia con el día (contenta, atenta, dormida).
            Semantics(
              label: describirNana(estado),
              child: AnimatedSwitcher(
                duration: suave,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: MascotaNana(
                  key: ValueKey(estado),
                  tamano: 64,
                  estado: estado,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_saludo()}, ${_yo?.nombre ?? ''}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: ColoresNana.morado,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hoy llevas ${_hechas(dia)} de ${dia.length}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: dia.isEmpty ? 0 : _hechas(dia) / dia.length,
                      ),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 12,
                        backgroundColor: ColoresNana.moradoClaro,
                        color: ColoresNana.ok,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Cuando cambia lo que toca, la tarjeta se desliza en vez de brincar.
        AnimatedSwitcher(
          duration: suave,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          ),
          child: TarjetaAhora(
            key: ValueKey('${que.name}-${actividad?.titulo}'),
            que: que,
            actividad: actividad,
            animo: animo,
            onHecha: () => _marcarHecha(actividad!),
            onAbrir: () => _abrirRecordatorio(actividad!),
            onAnimo: _anotarAnimo,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          child: TextButton.icon(
            onPressed: () => _ir(
              MiDia(
                folio: _folio,
                onHecha: _marcarHecha,
                onAbrir: _abrirRecordatorio,
              ),
            ),
            icon: const Icon(Icons.list_alt, size: 26),
            label: const Text('Ver todo mi día'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 56),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // No se encontró a qué adulto pertenece este celular (sin internet la
  // primera vez, o la sesión ya no está ligada). Sin folio no se puede leer
  // nada, así que en vez de tronar se explica y se ofrece salir.
  Widget _sinCuenta() {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Center(child: MascotaNana(tamano: 120)),
            const SizedBox(height: 24),
            const Text(
              'No pude encontrar tu cuenta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Revisa que tengas internet. Si sigue igual, pídele a tu familia '
              'un código nuevo y vuelve a entrar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _cargando = true);
                _cargar();
              },
              icon: const Icon(Icons.refresh, size: 28),
              label: const Text('Intentar de nuevo'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Servicios.repo.cerrarSesion();
                if (mounted) entrarA(context, const Bienvenida());
              },
              icon: const Icon(Icons.pin_outlined, size: 28),
              label: const Text('Entrar con un código'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 64),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargando && _yo == null) return _sinCuenta();
    return Scaffold(
      appBar: AppBar(
        actions: [
          BotonLeeme(texto: () => _textoInicio, color: ColoresNana.morado),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () =>
                  mostrarAjustesTexto(context, onCerrarSesion: _cerrarSesion),
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
      body: _cargando
          ? const EsqueletoCarga()
          : ConDia(folio: _folio, builder: _inicio),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    // Quien no habla "dice" tocando cuadros con ícono.
                    child: ValueListenableBuilder<bool>(
                      valueListenable: Ajustes.sinVoz,
                      builder: (context, sinVoz, _) => _BotonGrande(
                        icono: Icons.touch_app,
                        iconoB: sinVoz ? null : IconoB.hablar,
                        texto: sinVoz ? 'Decir' : 'Hablar',
                        fondo: ColoresNana.azul,
                        frente: Colors.white,
                        onTap: () => _ir(
                          sinVoz
                              ? TableroFrases(
                                  onFrase: _decir,
                                  onHablar: () => _ir(_nanaEscucha()),
                                )
                              : _nanaEscucha(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BotonGrande(
                      icono: Icons.family_restroom,
                      iconoB: IconoB.familia,
                      texto: 'Familia',
                      fondo: ColoresNana.moradoClaro,
                      frente: ColoresNana.morado,
                      onTap: () => _ir(MiFamilia(folio: _folio)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _BotonGrande(
                  icono: Icons.notifications_active,
                  iconoB: IconoB.ayuda,
                  texto: 'Necesito ayuda',
                  fondo: ColoresNana.alertaClaro,
                  frente: ColoresNana.alerta,
                  borde: ColoresNana.alerta,
                  enFila: true,
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

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color fondo;
  final Color frente;
  final Color? borde;
  final bool enFila; // ícono a un lado del texto, para el botón ancho
  final VoidCallback onTap;
  // Ícono propio de NANA; si no hay, se usa [icono] de Material.
  final IconoB? iconoB;

  const _BotonGrande({
    required this.icono,
    this.iconoB,
    required this.texto,
    required this.fondo,
    required this.frente,
    required this.onTap,
    this.borde,
    this.enFila = false,
  });

  @override
  Widget build(BuildContext context) {
    final partes = [
      if (iconoB case final b?)
        IconoNana(b, tamano: 34, color: frente)
      else
        Icon(icono, size: 34, color: frente),
      SizedBox(width: enFila ? 12 : 0, height: enFila ? 0 : 4),
      Flexible(
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: frente,
          ),
        ),
      ),
    ];
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
          constraints: BoxConstraints(minHeight: enFila ? 80 : 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          // Sin "alignment": con él, el Container se estira a toda la
          // altura disponible y la barra de abajo tapa la pantalla.
          child: enFila
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: partes,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: partes,
                ),
        ),
      ),
    );
  }
}
