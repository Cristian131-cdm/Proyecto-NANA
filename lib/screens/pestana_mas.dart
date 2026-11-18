import 'package:flutter/material.dart';

import '../core/permisos.dart';
import '../core/semana.dart' show avisoAlcance;
import '../core/servicios.dart';
import '../core/tema.dart';
import '../models/adulto.dart';
import '../widgets/tarjeta_dato.dart' show TarjetaDato;
import 'familia_alertas.dart';
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
            Renglon(
              icono: Icons.folder_outlined,
              texto: 'Su expediente',
              onTap: () => ir(
                ConBarra(
                  titulo: 'Su expediente',
                  child: permisos.verSalud
                      ? ResumenExpediente(
                          adulto: a.nombre,
                          folio: a.folio,
                          puedeEditar: permisos.editarSalud,
                        )
                      : ExpedientePrivado(adulto: a.nombre),
                ),
              ),
            ),
            Renglon(
              icono: Icons.family_restroom,
              texto: 'Familia y alertas',
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
        const SizedBox(height: 24),
        const Text(
          avisoAlcance,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: ColoresNana.tintaSuave),
        ),
      ],
    );
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
