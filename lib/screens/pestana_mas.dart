import 'package:flutter/material.dart';

import '../core/permisos.dart';
import '../core/semana.dart' show avisoAlcance;
import '../core/servicios.dart';
import '../core/tema.dart';
import '../data/repositorio.dart' show ErrorNana;
import '../models/adulto.dart';
import '../widgets/aviso.dart';
import '../widgets/tarjeta_dato.dart' show TarjetaDato;
import 'familia_alertas.dart';
import 'mis_alertas.dart';
import 'mis_ajustes.dart';
import 'pantalla_del_adulto.dart';
import 'resumen_expediente.dart';
import 'pestana_rutinas.dart';

// Pestaña «Más» de quien cuida: lo que no se usa a diario. Arriba lo de la
// persona (rutinas, expediente, familia y alertas, su pantalla) y abajo lo
// de quien cuida (sus ajustes, su cuenta, «Tus datos»).
class PestanaMas extends StatelessWidget {
  final Adulto adulto;
  const PestanaMas({super.key, required this.adulto});

  @override
  Widget build(BuildContext context) {
    final a = adulto;
    final permisos = Permisos.de(a, Servicios.repo.uid, Servicios.reloj());
    final esFamiliar = permisos.rol == RolCuidador.familiar;
    void ir(Widget pantalla) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

    final (estado, colorEstado) = a.uidAdulto != null
        ? ('Usa NANA en su celular', ColoresNana.ok)
        : a.tieneCelular
        ? ('Falta conectar su celular', ColoresNana.tintaSuave)
        : ('No tiene celular', ColoresNana.tintaSuave);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.phone_android, color: colorEstado, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                estado,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorEstado,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Titulo('De ${a.nombre}'),
        GrupoRenglones(
          children: [
            Renglon(
              icono: Icons.schedule,
              texto: 'Rutinas',
              nota: permisos.editarMedicinasYRutinas ? null : 'Solo ver',
              onTap: () => ir(
                ConBarra(
                  titulo: 'Rutinas de ${a.nombre}',
                  child: PestanaRutinas(
                    folio: a.folio,
                    puedeEditar: permisos.editarMedicinasYRutinas,
                  ),
                ),
              ),
            ),
            // El familiar no ve el expediente: ni la entrada se le muestra.
            if (permisos.verSalud)
              Renglon(
                icono: Icons.folder_outlined,
                texto: 'Su expediente',
                onTap: () => ir(
                  ConBarra(
                    titulo: 'Su expediente',
                    child: ResumenExpediente(
                      adulto: a.nombre,
                      folio: a.folio,
                      puedeEditar: permisos.editarSalud,
                    ),
                  ),
                ),
              ),
            Renglon(
              icono: Icons.family_restroom,
              texto: esFamiliar ? 'Quién más la cuida' : 'Familia y alertas',
              onTap: () => ir(FamiliaAlertas(adulto: a.nombre, folio: a.folio)),
            ),
            if (permisos.pantallaDelAdulto)
              Renglon(
                icono: Icons.phone_android,
                texto: 'Pantalla de ${a.nombre}',
                onTap: () =>
                    ir(PantallaDelAdulto(adulto: a.nombre, folio: a.folio)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _Titulo('Tuyo'),
        GrupoRenglones(
          children: [
            Renglon(
              icono: Icons.notifications_outlined,
              texto: 'Mis alertas',
              onTap: () => ir(MisAlertas(adulto: a.nombre)),
            ),
            Renglon(
              icono: Icons.text_fields,
              texto: 'Mis ajustes y cuenta',
              onTap: () => ir(MisAjustes(adulto: a)),
            ),
            Renglon(
              icono: Icons.shield_outlined,
              texto: 'Tus datos',
              onTap: () => ir(const PantallaPrivacidad()),
            ),
          ],
        ),
        if (permisos.rol != RolCuidador.principal) ...[
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => _dejarDeAcompanar(context, a),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 62),
              padding: const EdgeInsets.all(14),
              foregroundColor: ColoresNana.urgente,
              side: const BorderSide(color: ColoresNana.urgente, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(
              'Dejar de acompañar a ${a.nombre}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          avisoAlcance,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: ColoresNana.tintaSuave),
        ),
      ],
    );
  }

  Future<void> _dejarDeAcompanar(BuildContext context, Adulto a) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('¿Dejar de acompañar a ${a.nombre}?'),
        content: Text(
          'Ya no verás su día ni te llegarán sus alertas. Para volver, te '
          'tienen que invitar con un código nuevo.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ColoresNana.urgente),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (si != true) return;
    try {
      await Servicios.repo.dejarDeAcompanar(a.folio);
      if (context.mounted) {
        mostrarAviso(context, 'Ya no acompañas a ${a.nombre}');
      }
    } on ErrorNana catch (e) {
      if (context.mounted) mostrarAviso(context, e.mensaje);
    }
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: ColoresNana.tintaSuave,
      ),
    ),
  );
}

// Una pestaña de antes (Rutinas, Historial) abierta como pantalla propia.
class ConBarra extends StatelessWidget {
  final String titulo;
  final Widget child;
  const ConBarra({super.key, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: SafeArea(top: false, child: child),
  );
}

// Lo que ve el familiar invitado en «Su expediente».
class ExpedientePrivado extends StatelessWidget {
  final String adulto;
  const ExpedientePrivado({super.key, required this.adulto});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      TarjetaDato(
        icono: Icons.lock_outline,
        titulo: 'El expediente de $adulto es privado',
        subtitulo:
            'Sus datos de salud, recetas y citas solo los ven quien la dio '
            'de alta y su suplente.',
      ),
    ],
  );
}
