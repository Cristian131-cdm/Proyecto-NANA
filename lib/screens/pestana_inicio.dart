import 'package:flutter/material.dart';

import '../core/ajustes.dart';
import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../widgets/aviso.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/tarjeta_dato.dart';
import '../widgets/icono_nana.dart';
import 'alerta_ayuda.dart';

// Lo que el cuidador ve al abrir NANA: alertas, cómo va el día y la línea
// de tiempo. Todo llega en tiempo real de Firestore.
class PestanaInicio extends StatefulWidget {
  final Adulto adulto;
  const PestanaInicio({super.key, required this.adulto});

  @override
  State<PestanaInicio> createState() => _PestanaInicioState();
}

class _PestanaInicioState extends State<PestanaInicio> {
  // Se crean una vez para no volver a suscribirse en cada redibujo.
  late final _meds = Servicios.repo.medicamentos(widget.adulto.folio);
  late final _hoy = Servicios.repo.registrosDeHoy(widget.adulto.folio);
  late final _alertas = Servicios.repo.alertasSinAtender(widget.adulto.folio);
  late final _rutinas = Servicios.repo.rutinas(widget.adulto.folio);
  late final _reglas = Servicios.repo.reglasAlerta(widget.adulto.folio);
  late final _ultima = Servicios.repo.ultimaActividad(widget.adulto.folio);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Registro>>(
        stream: _hoy,
        builder: (context, regs) => StreamBuilder<List<Alerta>>(
          stream: _alertas,
          builder: (context, alertas) => StreamBuilder<List<Rutina>>(
            stream: _rutinas,
            builder: (context, rutinas) => StreamBuilder<ReglasAlerta>(
              stream: _reglas,
              builder: (context, reglas) => StreamBuilder<DateTime?>(
                stream: _ultima,
                builder: (context, ultima) => ListenableBuilder(
                  listenable: Listenable.merge([
                    Ajustes.callarMedicina,
                    Ajustes.callarSinNoticias,
                  ]),
                  builder: (context, _) => _Contenido(
                    adulto: widget.adulto,
                    meds: meds.data ?? const [],
                    hoy: regs.data ?? const [],
                    alertas: alertas.data ?? const [],
                    rutinas: rutinas.data ?? const [],
                    reglas: reglas.data ?? const ReglasAlerta(),
                    ultima: ultima.data,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  final Adulto adulto;
  final List<Medicamento> meds;
  final List<Registro> hoy;
  final List<Alerta> alertas;
  final List<Rutina> rutinas;
  final ReglasAlerta reglas;
  final DateTime? ultima;

  const _Contenido({
    required this.adulto,
    required this.rutinas,
    required this.reglas,
    required this.ultima,
    required this.meds,
    required this.hoy,
    required this.alertas,
  });

  // El cuidador confirma por el adulto (sobre todo si no tiene celular).
  Future<void> _yaLaTomo(BuildContext context, Medicamento m) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '¿${adulto.nombre} ya se tomó su ${m.nombre}?',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Todavía no', style: TextStyle(fontSize: 20)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, ya se la tomó',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    );
    if (si != true) return;
    final id = await Servicios.repo.registrar(
      adulto.folio,
      Registro(
        tipo: TipoActividad.medicina,
        titulo: '${m.nombre} ${m.dosis}',
        idMedicamento: m.id,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
    );
    if (!context.mounted) return;
    mostrarAviso(
      context,
      'Anoté que ${adulto.nombre} ya se tomó su ${m.nombre}',
      onDeshacer: () => Servicios.repo.borrarRegistro(adulto.folio, id),
    );
  }

  Color _colorAnimo(int? valor) {
    if (valor == null || valor == 2) return ColoresNana.tinta;
    return valor < 2 ? ColoresNana.ok : ColoresNana.alerta;
  }

  @override
  Widget build(BuildContext context) {
    final nombre = adulto.nombre;
    final telefono = adulto.telefono;
    final ahora = Servicios.reloj();
    // Las reglas son de la familia; «Mis alertas» calla algunas solo aquí.
    final vencidas = reglas.medicina && !Ajustes.callarMedicina.value
        ? sinConfirmar(meds: meds, hoy: hoy, ahora: ahora)
        : const <Medicamento>[];
    final callado =
        reglas.sinNoticias &&
        !Ajustes.callarSinNoticias.value &&
        sinNoticias(
          ultima: ultima,
          ahora: ahora,
          horas: reglas.horasSinNoticias,
        );
    final dia = diaDelAdulto(
      meds: meds,
      hoy: hoy,
      otras: rutinasDeHoy(rutinas, ahora),
    );
    final linea = lineaDelCuidador(meds: meds, hoy: hoy, ahora: ahora);
    final VoidCallback? llamarle = telefono == null
        ? null
        : () => llamar(context, telefono);

    int hechas(TipoActividad t) => dia
        .where((a) => a.tipo == t && a.estado == EstadoActividad.hecha)
        .length;
    int total(TipoActividad t) => dia.where((a) => a.tipo == t).length;
    final tomadas = hechas(TipoActividad.medicina);
    final listas = dia.where((a) => a.estado == EstadoActividad.hecha).length;
    final animos = hoy.where((r) => r.tipo == TipoActividad.animo);
    final animo = animos.isEmpty ? null : animos.last.valor;

    final pendientes = dia
        .where((a) => a.estado != EstadoActividad.hecha)
        .take(2)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final a in ordenarAlertas(alertas)) ...[
          _Alerta(
            icono: a.esFrase
                ? Icons.chat_bubble_outline
                : Icons.notifications_active_outlined,
            titulo: a.esFrase
                ? '$nombre dijo: "${a.texto ?? ''}"'
                : a.noContesto
                ? '$nombre pidió ayuda y no contesta'
                : '$nombre pidió ayuda',
            detalle: [
              if (!a.esFrase) a.comoSePidio,
              'A las ${horaCorta(TimeOfDay.fromDateTime(a.fecha))}',
              for (final r in a.respuestas.values)
                if (!r.atendio && r.nombre.isNotEmpty)
                  '${r.nombre} va para allá',
            ].join(' · '),
            onLlamar: llamarle,
            textoResuelta: a.esFrase ? 'Ya lo vi' : 'Ya lo atendí',
            onResuelta: () => a.esFrase
                ? Servicios.repo.atenderAlerta(adulto.folio, a.id)
                : Servicios.repo.responderAlerta(adulto.folio, a.id, 'atendi'),
            onAbrir: a.esFrase
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlertaAyuda(adulto: adulto, alerta: a),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
        ],
        for (final m in vencidas) ...[
          _Alerta(
            icono: Icons.medication_outlined,
            titulo: '${m.nombre} · ${horaCorta(m.hora)}',
            detalle: 'Sin confirmar',
            onLlamar: llamarle,
            textoResuelta: 'Ya la tomó',
            onResuelta: () => _yaLaTomo(context, m),
          ),
          const SizedBox(height: 12),
        ],
        if (callado) ...[
          _Alerta(
            icono: Icons.hourglass_bottom,
            titulo: 'Sin noticias de $nombre',
            detalle: 'Desde las ${horaCorta(TimeOfDay.fromDateTime(ultima!))}',
            onLlamar: llamarle,
          ),
          const SizedBox(height: 12),
        ],
        if (alertas.isEmpty && vencidas.isEmpty && !callado)
          _EstadoBien(adulto: nombre),
        TituloSeccion('Hoy · $listas de ${dia.length}'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Circulo(
                etiqueta: 'Medicinas',
                valor: '$tomadas/${meds.length}',
                color: vencidas.isNotEmpty
                    ? ColoresNana.alerta
                    : meds.isNotEmpty && tomadas == meds.length
                    ? ColoresNana.ok
                    : null,
              ),
            ),
            Expanded(
              child: _Circulo(
                etiqueta: 'Comidas',
                valor:
                    '${hechas(TipoActividad.comida)}/${total(TipoActividad.comida)}',
              ),
            ),
            Expanded(
              child: _Circulo(
                etiqueta: animo == null
                    ? 'Ánimo'
                    : CaritasAnimo.etiquetas[animo],
                icono: _caraDe(animo),
                color: _colorAnimo(animo),
                lectura: animo == null
                    ? 'Ánimo: todavía no dice'
                    : 'Ánimo: ${CaritasAnimo.etiquetas[animo]}',
              ),
            ),
            Expanded(
              child: _Circulo(
                etiqueta: 'Moverse',
                valor:
                    '${hechas(TipoActividad.ejercicio)}/${total(TipoActividad.ejercicio)}',
              ),
            ),
          ],
        ),
        const TituloSeccion('Lo que sigue'),
        if (pendientes.isEmpty)
          Text(
            '$nombre ya hizo todo lo de hoy.',
            style: const TextStyle(fontSize: 18),
          ),
        for (final a in pendientes) ...[
          SuperficieCuidador(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    a.hora,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColoresNana.morado,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(a.titulo, style: const TextStyle(fontSize: 19)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _DiaCompleto(
          linea: linea,
          sinCelular: !adulto.tieneCelular,
          nombre: nombre,
          onTomar: (a) => _yaLaTomo(
            context,
            meds.firstWhere((m) => m.id == a.idMedicamento),
          ),
        ),
      ],
    );
  }

  // Carita para el ánimo (0 muy bien … 4 muy mal), para no depender del texto.
  IconData _caraDe(int? valor) => switch (valor) {
    null => Icons.help_outline,
    0 => Icons.sentiment_very_satisfied,
    1 => Icons.sentiment_satisfied,
    2 => Icons.sentiment_neutral,
    3 => Icons.sentiment_dissatisfied,
    _ => Icons.sentiment_very_dissatisfied,
  };
}

// «Ver todo el día»: la línea de tiempo completa, guardada para que la
// pestaña quede corta.
class _DiaCompleto extends StatefulWidget {
  final List<Actividad> linea;
  final bool sinCelular;
  final String nombre;
  final ValueChanged<Actividad> onTomar;

  const _DiaCompleto({
    required this.linea,
    required this.sinCelular,
    required this.nombre,
    required this.onTomar,
  });

  @override
  State<_DiaCompleto> createState() => _DiaCompletoState();
}

class _DiaCompletoState extends State<_DiaCompleto> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final linea = widget.linea;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _abierto = !_abierto),
            icon: Icon(
              _abierto ? Icons.expand_less : Icons.expand_more,
              size: 28,
            ),
            label: Text(_abierto ? 'Ocultar el día' : 'Ver todo el día'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 52),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (_abierto) ...[
          if (linea.isEmpty)
            const Text(
              'Todavía no hay nada anotado hoy.',
              style: TextStyle(fontSize: 18),
            ),
          for (var i = 0; i < linea.length; i++)
            _Evento(
              actividad: linea[i],
              ultimo: i == linea.length - 1,
              onTap:
                  linea[i].tipo == TipoActividad.medicina &&
                      linea[i].estado != EstadoActividad.hecha
                  ? () => widget.onTomar(linea[i])
                  : null,
            ),
          if (widget.sinCelular) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.nombre} no tiene celular: toca una medicina para '
              'anotar que ya la tomó.',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ],
      ],
    );
  }
}

// Un círculo de «Hoy»: número (o carita) y una palabra abajo.
class _Circulo extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final IconData? icono;
  final Color? color;
  final String? lectura;

  const _Circulo({
    required this.etiqueta,
    this.valor,
    this.icono,
    this.color,
    this.lectura,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? ColoresNana.tinta;
    return Semantics(
      label: lectura ?? '$etiqueta: ${valor ?? ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == ColoresNana.ok
                  ? ColoresNana.okClaro
                  : color == ColoresNana.alerta
                  ? ColoresNana.alertaClaro
                  : Colors.white,
              border: Border.all(
                color: color ?? const Color(0xFFDDD6F3),
                width: 4,
              ),
            ),
            child: icono != null
                ? Icon(icono, color: c, size: 34)
                : FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        valor ?? '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: c,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// Algo que necesita atención: ícono, una línea corta y qué hacer.
class _Alerta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? onLlamar; // null si no hay teléfono guardado
  final String? textoResuelta; // null: la alerta se quita sola
  final VoidCallback? onResuelta;
  // «Pidió ayuda»: abre la pantalla completa con «Ya voy».
  final VoidCallback? onAbrir;

  const _Alerta({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onLlamar,
    this.textoResuelta,
    this.onResuelta,
    this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresNana.alertaClaro,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColoresNana.alerta, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: ColoresNana.alerta,
                child: Icon(icono, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: ColoresNana.alerta,
                      ),
                    ),
                    Text(detalle, style: const TextStyle(fontSize: 17)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ColumnasCuidador(
            children: [
              if (onLlamar != null)
                FilledButton.icon(
                  onPressed: onLlamar,
                  icon: const Icon(Icons.call),
                  label: const Text('Llamar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 60),
                    padding: const EdgeInsets.all(14),
                    backgroundColor: ColoresNana.alerta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (textoResuelta != null)
                OutlinedButton(
                  onPressed: onResuelta,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 60),
                    padding: const EdgeInsets.all(14),
                    foregroundColor: ColoresNana.alerta,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: ColoresNana.alerta, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(textoResuelta!, textAlign: TextAlign.center),
                ),
            ],
          ),
          if (onAbrir != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAbrir,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: ColoresNana.alerta,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Avisar que voy ›'),
              ),
            ),
        ],
      ),
    );
  }
}

class _EstadoBien extends StatelessWidget {
  final String adulto;
  const _EstadoBien({required this.adulto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresNana.okClaro,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: ColoresNana.ok, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$adulto va bien hoy',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _Evento extends StatelessWidget {
  final Actividad actividad;
  final bool ultimo;
  final VoidCallback? onTap; // anotar una medicina por el adulto

  const _Evento({required this.actividad, this.ultimo = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = actividad.estado;
    final color = estado.color;
    final resaltar = estado == EstadoActividad.sinConfirmar;
    final apagado = estado == EstadoActividad.pendiente;

    final fila = Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 10),
      child: SuperficieCuidador(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: IconoActividad(actividad.tipo, color: color, tamano: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actividad.hora,
                    style: const TextStyle(
                      fontSize: 16,
                      color: ColoresNana.tintaSuave,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    actividad.titulo,
                    style: TextStyle(
                      fontSize: 18,
                      color: resaltar
                          ? ColoresNana.alerta
                          : apagado
                          ? ColoresNana.tintaSuave
                          : ColoresNana.tinta,
                      fontWeight: resaltar
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: ColoresNana.morado),
          ],
        ),
      ),
    );
    if (onTap == null) return fila;
    return Semantics(
      button: true,
      hint: 'Anotar que ya la tomó',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: fila,
      ),
    );
  }
}
