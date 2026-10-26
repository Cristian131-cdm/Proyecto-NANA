import 'package:flutter/material.dart';

import '../core/dia.dart';
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../widgets/aviso.dart';
import '../widgets/caritas_animo.dart';
import '../widgets/tarjeta_dato.dart';

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicamento>>(
      stream: _meds,
      builder: (context, meds) => StreamBuilder<List<Registro>>(
        stream: _hoy,
        builder: (context, regs) => StreamBuilder<List<Alerta>>(
          stream: _alertas,
          builder: (context, alertas) => _Contenido(
            adulto: widget.adulto,
            meds: meds.data ?? const [],
            hoy: regs.data ?? const [],
            alertas: alertas.data ?? const [],
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

  const _Contenido({
    required this.adulto,
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
            child: const Text('No', style: TextStyle(fontSize: 20)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, ya', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
    if (si != true) return;
    await Servicios.repo.registrar(
      adulto.folio,
      Registro(
        tipo: TipoActividad.medicina,
        titulo: '${m.nombre} ${m.dosis}',
        idMedicamento: m.id,
        fecha: Servicios.reloj(),
        registradoPor: Servicios.repo.uid ?? '',
      ),
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
    final vencidas = sinConfirmar(meds: meds, hoy: hoy, ahora: ahora);
    final dia = diaDelAdulto(meds: meds, hoy: hoy);
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        for (final a in alertas) ...[
          _Alerta(
            titulo: '$nombre pidió ayuda',
            detalle:
                'Tocó "Avisar a mi familia" a las '
                '${horaCorta(TimeOfDay.fromDateTime(a.fecha))}.',
            onLlamar: llamarle,
            textoResuelta: 'Ya lo atendí',
            onResuelta: () => Servicios.repo.atenderAlerta(adulto.folio, a.id),
          ),
          const SizedBox(height: 12),
        ],
        for (final m in vencidas) ...[
          _Alerta(
            titulo: '${m.nombre} de las ${horaCorta(m.hora)} sin confirmar',
            detalle:
                'Ya pasaron los ${m.ventanaMin} minutos y $nombre no ha '
                'dicho que la tomó.',
            onLlamar: llamarle,
            textoResuelta: 'Ya la tomó',
            onResuelta: () => _yaLaTomo(context, m),
          ),
          const SizedBox(height: 12),
        ],
        if (alertas.isEmpty && vencidas.isEmpty) _EstadoBien(adulto: nombre),
        TituloSeccion('Hoy lleva $listas de ${dia.length}'),
        Row(
          children: [
            Expanded(
              child: _Recuadro(
                icono: Icons.medication,
                titulo: 'Medicinas',
                valor: '$tomadas / ${meds.length}',
                color: vencidas.isNotEmpty
                    ? ColoresNana.alerta
                    : meds.isNotEmpty && tomadas == meds.length
                    ? ColoresNana.ok
                    : ColoresNana.tinta,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Recuadro(
                icono: Icons.restaurant,
                titulo: 'Comidas',
                valor:
                    '${hechas(TipoActividad.comida)} / '
                    '${total(TipoActividad.comida)}',
                color: ColoresNana.tinta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Recuadro(
                icono: Icons.mood,
                titulo: 'Ánimo',
                valor: animo == null
                    ? 'Sin dato'
                    : CaritasAnimo.etiquetas[animo],
                color: _colorAnimo(animo),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Recuadro(
                icono: Icons.directions_walk,
                titulo: 'Actividad',
                valor:
                    '${hechas(TipoActividad.ejercicio)} / '
                    '${total(TipoActividad.ejercicio)}',
                color: ColoresNana.tinta,
              ),
            ),
          ],
        ),
        const TituloSeccion('Su día'),
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
                ? () => _yaLaTomo(
                    context,
                    meds.firstWhere((m) => m.id == linea[i].idMedicamento),
                  )
                : null,
          ),
        if (!adulto.tieneCelular) ...[
          const SizedBox(height: 8),
          Text(
            '$nombre no tiene celular: toca una medicina para anotar '
            'que ya la tomó.',
            style: const TextStyle(fontSize: 16),
          ),
        ],
        const SizedBox(height: 24),
        if (llamarle != null)
          SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: llamarle,
              icon: const Icon(Icons.call),
              label: Text('Llamar a $nombre'),
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
        const SizedBox(height: 16),
        const Text(
          'NANA solo registra, recuerda y alerta. No da recomendaciones médicas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B6485)),
        ),
      ],
    );
  }
}

class _Alerta extends StatelessWidget {
  final String titulo;
  final String detalle;
  final VoidCallback? onLlamar; // null si no hay teléfono guardado
  final String textoResuelta;
  final VoidCallback onResuelta;

  const _Alerta({
    required this.titulo,
    required this.detalle,
    required this.onLlamar,
    required this.textoResuelta,
    required this.onResuelta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Icon(
                Icons.warning_amber_rounded,
                color: ColoresNana.alerta,
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ColoresNana.alerta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(detalle, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onLlamar != null) ...[
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: onLlamar,
                      icon: const Icon(Icons.call),
                      label: const Text('Llamar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresNana.alerta,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onResuelta,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColoresNana.alerta,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: ColoresNana.alerta),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text(textoResuelta),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ColoresNana.okClaro,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: ColoresNana.ok, size: 44),
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

class _Recuadro extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _Recuadro({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColoresNana.moradoClaro, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: const Color(0xFF6B6485)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B6485),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // El ícono repite lo que dice el color, para quien no distingue
          // el verde del naranja.
          Row(
            children: [
              if (color == ColoresNana.ok)
                const Icon(Icons.check_circle, color: ColoresNana.ok, size: 22)
              else if (color == ColoresNana.alerta)
                const Icon(
                  Icons.warning_amber_rounded,
                  color: ColoresNana.alerta,
                  size: 22,
                ),
              if (color == ColoresNana.ok || color == ColoresNana.alerta)
                const SizedBox(width: 6),
              Flexible(
                child: Text(
                  valor,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
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

    final fila = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                actividad.hora,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(actividad.tipo.icono, color: color, size: 22),
              ),
              if (!ultimo)
                Expanded(
                  child: Container(width: 2, color: ColoresNana.moradoClaro),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 9, bottom: ultimo ? 0 : 24),
              child: Text(
                actividad.titulo,
                style: TextStyle(
                  fontSize: 18,
                  color: resaltar
                      ? ColoresNana.alerta
                      : apagado
                      ? const Color(0xFF8A82A3)
                      : ColoresNana.tinta,
                  fontWeight: resaltar ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
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
