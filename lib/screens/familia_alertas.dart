import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/codigo.dart';
import '../core/medicion.dart';
import '../core/permisos.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart';
import 'arranque.dart';
import 'pantalla_del_adulto.dart';

// Lo que se manda por WhatsApp con el código de invitación.
String textoInvitacion(String adulto, String codigo) =>
    'Te invito a cuidar a $adulto en NANA.\n'
    '1. Descarga NANA y toca "Me invitaron".\n'
    '2. Escribe este código: '
    '${formatearCodigo(codigo)}\n'
    '3. Llena tus datos para crear tu cuenta.\n'
    'El código sirve una sola vez y vence en 24 horas.';

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
  // Para saber quién es el principal y quién el suplente.
  late final _adultos = Servicios.repo.adultosACargo();

  void _guardar(ReglasAlerta r) =>
      Servicios.repo.guardarReglasAlerta(widget.folio, r);

  // Qué papel tiene cada quien con esta persona.
  String _papel(Familiar f, Adulto? a) {
    if (a == null) return 'Familiar';
    if (a.creadoPor == f.uid) return nombreRol(RolCuidador.principal);
    final s = a.suplente;
    if (s != null && s.uid == f.uid && s.vigente(Servicios.reloj())) {
      return 'Suplente ${vigenciaSuplente(s)}';
    }
    return nombreRol(RolCuidador.familiar);
  }

  Future<void> _hacer(Future<void> Function() accion, String listo) async {
    try {
      await accion();
      if (mounted) mostrarAviso(context, listo);
    } on ErrorNana catch (e) {
      if (mounted) mostrarAviso(context, e.mensaje);
    }
  }

  // "Sin fecha de fin" (hasta que el principal lo quite) o "Hasta una fecha".
  Future<void> _nombrarSuplente(Familiar f) async {
    final opcion = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('¿Hasta cuándo queda ${f.nombre} como suplente?'),
        children: [
          for (final (clave, icono, texto, detalle) in const [
            ('fecha', Icons.event, 'Hasta una fecha', 'Se quita sola ese día'),
            (
              'siempre',
              Icons.all_inclusive,
              'Sin fecha de fin',
              'Hasta que tú la quites',
            ),
          ])
            ListTile(
              leading: Icon(icono, color: ColoresNana.morado, size: 30),
              title: Text(texto, style: const TextStyle(fontSize: 20)),
              subtitle: Text(detalle, style: const TextStyle(fontSize: 15)),
              onTap: () => Navigator.pop(context, clave),
            ),
        ],
      ),
    );
    if (opcion == null || !mounted) return;
    DateTime? hasta;
    if (opcion == 'fecha') {
      final hoy = DateUtils.dateOnly(Servicios.reloj());
      final dia = await showDatePicker(
        context: context,
        helpText: 'Último día como suplente',
        initialDate: hoy.add(const Duration(days: 7)),
        firstDate: hoy,
        lastDate: hoy.add(const Duration(days: 365)),
      );
      if (dia == null) return;
      // Vale todo ese día.
      hasta = dia.add(const Duration(hours: 23, minutes: 59));
    }
    await _hacer(
      () => Servicios.repo.nombrarSuplente(widget.folio, f.uid, hasta: hasta),
      '${f.nombre} queda como suplente',
    );
  }

  Future<void> _quitarFamiliar(Familiar f) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('¿Quitar a ${f.nombre}?'),
        content: Text(
          'Ya no verá a ${widget.adulto} ni recibirá sus alertas. Si después '
          'quieres que vuelva, la invitas con un código nuevo.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, quitar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    await _hacer(
      () => Servicios.repo.quitarFamiliar(widget.folio, f.uid),
      'Quité a ${f.nombre}',
    );
  }

  void _verFamiliar(Familiar f, bool soyYo, Adulto? a, Permisos p) {
    final telefono = f.telefono;
    final esPrincipal = a?.creadoPor == f.uid;
    final esSuplente = a?.suplente?.uid == f.uid;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (hoja) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                soyYo ? '${f.nombre} (tú)' : f.nombre,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_papel(f, a)} · recibe todas las alertas',
                style: const TextStyle(
                  fontSize: 16,
                  color: ColoresNana.tintaSuave,
                ),
              ),
              if (telefono != null && telefono.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Teléfono: $telefono',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
              if (!soyYo && telefono != null && telefono.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => llamar(context, telefono),
                    icon: const Icon(Icons.call),
                    label: Text('Llamar a ${f.nombre}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresNana.azul,
                      minimumSize: const Size(0, 60),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              // Lo que solo decide quien dio de alta a la persona.
              if (p.nombrarSuplente && !esPrincipal) ...[
                const SizedBox(height: 12),
                BotonSecundario(
                  icono: esSuplente
                      ? Icons.person_remove_alt_1_outlined
                      : Icons.swap_horiz,
                  texto: esSuplente
                      ? 'Quitar como suplente'
                      : 'Dejar como suplente',
                  onPressed: () {
                    Navigator.pop(hoja);
                    if (esSuplente) {
                      _hacer(
                        () => Servicios.repo.quitarSuplente(widget.folio),
                        '${f.nombre} ya no es suplente',
                      );
                    } else {
                      _nombrarSuplente(f);
                    }
                  },
                ),
              ],
              if (p.quitarPersonas && !esPrincipal) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(hoja);
                    _quitarFamiliar(f);
                  },
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Quitar de la familia'),
                  style: TextButton.styleFrom(
                    foregroundColor: ColoresNana.alerta,
                    minimumSize: const Size(0, 56),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _borrarTodo() async {
    final adulto = widget.adulto;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('¿Borrar todo lo de $adulto?'),
        content: Text(
          'Se borran sus medicinas, rutinas, registros, recetas, citas, datos '
          'de salud y alertas, para toda la familia. $adulto ya no podrá '
          'usar NANA con su código. No se puede deshacer.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, conservar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ColoresNana.alerta),
            child: const Text('Sí, borrar todo'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    try {
      // Las fotos de sus recetas que estén en este celular también se van.
      final recetas = await Servicios.repo.recetas(widget.folio).first;
      for (final r in recetas) {
        if (r.id != null) await Servicios.fotos.borrar(r.id!);
      }
      await Servicios.repo.borrarAdulto(widget.folio);
      final destino = await destinoInicial();
      if (!mounted) return;
      entrarA(context, destino);
    } on ErrorNana catch (e) {
      if (mounted) mostrarAviso(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familia y alertas')),
      body: StreamBuilder<List<Adulto>>(
        stream: _adultos,
        builder: (context, adultos) {
          final a = (adultos.data ?? const <Adulto>[])
              .where((x) => x.folio == widget.folio)
              .firstOrNull;
          // Mientras no se sabe quién es quién, no se ofrece nada de admin.
          final p = a == null
              ? const Permisos(RolCuidador.familiar)
              : Permisos.de(a, Servicios.repo.uid, Servicios.reloj());
          return StreamBuilder<List<Familiar>>(
            stream: _familia,
            builder: (context, familia) => StreamBuilder<ReglasAlerta>(
              stream: _reglas,
              builder: (context, reglas) => _lista(
                familia.data ?? const [],
                reglas.data ?? const ReglasAlerta(),
                a,
                p,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _lista(
    List<Familiar> familia,
    ReglasAlerta reglas,
    Adulto? a,
    Permisos p,
  ) {
    final adulto = widget.adulto;
    final yo = Servicios.repo.uid;
    final suplente = a?.suplente;
    final suplenteActivo =
        suplente != null && suplente.vigente(Servicios.reloj());
    final nombreSuplente = familia
        .where((f) => f.uid == suplente?.uid)
        .firstOrNull
        ?.nombre;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (suplenteActivo && nombreSuplente != null)
          TarjetaDato(
            icono: Icons.swap_horiz,
            titulo: 'Suplente activo: $nombreSuplente',
            subtitulo:
                '${vigenciaSuplente(suplente)[0].toUpperCase()}'
                '${vigenciaSuplente(suplente).substring(1)}',
            color: ColoresNana.azul,
          ),
        TituloSeccion('Quién acompaña a $adulto'),
        for (final f in familia)
          TarjetaDato(
            icono: Icons.person,
            titulo: f.uid == yo ? 'Tú (${f.nombre})' : f.nombre,
            subtitulo: (f.telefono ?? '').isEmpty
                ? _papel(f, a)
                : '${_papel(f, a)} · ${f.telefono}',
            onTap: () => _verFamiliar(f, f.uid == yo, a, p),
          ),
        // Invitar con código vive arriba de la pestaña Más (un solo lugar).
        if (!p.invitar)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Solo la persona encargada invita y cambia las alertas.',
              style: TextStyle(fontSize: 15, color: ColoresNana.tintaSuave),
            ),
          ),
        const TituloSeccion('Avísame si…'),
        _Regla(
          icono: Icons.medication,
          titulo: 'Medicina sin confirmar',
          subtitulo: 'Cuando pasa su ventana',
          encendida: reglas.medicina,
          onCambio: p.cambiarAlertas
              ? (v) => _guardar(reglas.copyWith(medicina: v))
              : null,
        ),
        _Regla(
          icono: Icons.schedule,
          titulo: 'Sin noticias',
          subtitulo: '${reglas.horasSinNoticias} horas sin registros',
          encendida: reglas.sinNoticias,
          onCambio: p.cambiarAlertas
              ? (v) => _guardar(reglas.copyWith(sinNoticias: v))
              : null,
          extra: reglas.sinNoticias && p.cambiarAlertas
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
          subtitulo: 'Siempre. No se apaga.',
          encendida: true,
        ),
        if (p.pantallaDelAdulto) ...[
          TituloSeccion('El celular de $adulto'),
          TarjetaDato(
            icono: Icons.phone_android,
            titulo: 'Pantalla de $adulto',
            subtitulo: 'Cómo ve NANA en su celular',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PantallaDelAdulto(adulto: adulto, folio: widget.folio),
              ),
            ),
          ),
        ],
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
        if (p.borrarDatos)
          _Regla(
            icono: Icons.insights_outlined,
            titulo: 'Ayudar a mejorar NANA',
            subtitulo:
                'Anónimo: qué pantallas se usan. Sin nombres, medicinas ni '
                'lo que se escribe.',
            encendida: a?.estudio ?? false,
            onCambio: (v) => _hacer(
              () => Servicios.repo.guardarEstudio(widget.folio, v),
              v ? 'Gracias. Lo puedes apagar aquí mismo' : 'Apagado',
            ),
          ),
        if (p.borrarDatos)
          TarjetaDato(
            icono: Icons.delete_forever_outlined,
            titulo: 'Borrar todos los datos de $adulto',
            subtitulo: 'No se puede deshacer',
            color: ColoresNana.alerta,
            onTap: _borrarTodo,
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
      'Lo mínimo y con tu permiso: las medicinas y rutinas que registra la '
          'familia, cuándo se confirmaron, cómo se sintió (las caritas), los '
          'datos de salud y recetas que la familia escribe, y las alertas.',
    ),
    (
      Icons.no_photography_outlined,
      'Tus documentos no se suben',
      'NANA nunca guarda en la nube la foto o el PDF de una receta o '
          'expediente. Si agregas la foto de una receta, se queda solo en el '
          'celular donde la agregaste: nadie más la ve y se borra si '
          'desinstalas NANA.',
    ),
    (
      Icons.group_outlined,
      'Quién lo ve',
      'Solo la persona mayor y la familia que se unió con un código de '
          'invitación. Nadie más, y NANA no vende ni comparte datos.',
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
    (
      Icons.insights_outlined,
      'Estudio de uso (opcional)',
      'Si quien dio de alta lo prende, NANA anota de forma anónima qué '
          'pantallas se abren, cuánto tiempo y dónde la gente se regresa, '
          'para mejorar la app. No anota nombres, medicinas, datos de salud '
          'ni lo que se escribe. Se apaga cuando quieras.',
    ),
    (
      Icons.delete_outline,
      'Borrar los datos',
      'Quien dio de alta a la persona puede borrar todo lo suyo desde '
          '"Familia y alertas". Se borra de inmediato y no se puede recuperar.',
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

// Crea un código de invitación para que alguien de la familia acompañe a
// [adulto] y lo muestra con Copiar y Compartir. Lo usan «Familia y alertas»
// y el botón grande de la pestaña Más.
Future<void> invitarConCodigo(
  BuildContext context, {
  required String folio,
  required String adulto,
}) async {
  final String codigo;
  try {
    codigo = (await Servicios.repo.generarCodigo(folio, familiar: true)).codigo;
  } on ErrorNana catch (e) {
    if (context.mounted) mostrarAviso(context, e.mensaje);
    return;
  }
  if (!context.mounted) return;
  Medicion.tarea('invitacion_creada');
  final texto = textoInvitacion(adulto, codigo);
  showDialog<void>(
    context: context,
    builder: (dialogo) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Código de invitación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            formatearCodigo(codigo),
            semanticsLabel: codigo.split('').join(' '),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: ColoresNana.morado,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sirve una sola vez y vence en 24 horas. Tu familiar abre '
            'NANA y toca "Me invitaron".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: ColoresNana.tintaSuave),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: codigo));
            Navigator.pop(dialogo);
            mostrarAviso(context, 'Código copiado');
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
