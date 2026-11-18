import '../models/apariencia.dart';
import 'ajustes.dart';

// Cómo se adapta el celular del adulto a las discapacidades que anotó su
// familia en los datos de salud (Salud.opcionesDiscapacidad).
// La familia sugiere, la persona decide: se aplica una vez por cada cambio
// de la lista y después se respeta lo que el adulto elija en "Aa".
class PerfilAccesibilidad {
  final bool sinVoz;
  final bool pantallaEsBoton;
  final double? escalaTexto; // mínimo sugerido
  final bool queMeHable;
  final bool conSenas;
  final bool altoContraste;
  final bool avisoVibracion;

  const PerfilAccesibilidad({
    this.sinVoz = false,
    this.pantallaEsBoton = false,
    this.escalaTexto,
    this.queMeHable = false,
    this.conSenas = false,
    this.altoContraste = false,
    this.avisoVibracion = false,
  });
}

PerfilAccesibilidad perfilDe(List<String> discapacidades) {
  final noVe = discapacidades.contains('No ve bien');
  final noOye = discapacidades.contains('No oye bien');
  final noHabla = discapacidades.contains('No habla');
  final daltonismo = discapacidades.contains('Daltonismo');
  return PerfilAccesibilidad(
    sinVoz: noHabla,
    pantallaEsBoton: noVe,
    escalaTexto: noVe ? 1.5 : null,
    queMeHable: noVe,
    conSenas: noOye,
    altoContraste: noVe || daltonismo,
    avisoVibracion: noOye,
  );
}

// Solo prende lo sugerido (nunca apaga lo que el adulto eligió). "Sin voz" y
// "pantalla como botón" sí siguen a la lista, porque dependen solo de ella.
void aplicarPerfil(List<String> discapacidades) {
  final clave = ([...discapacidades]..sort()).join('|');
  if (clave == Ajustes.discapacidadesAplicadas.value) return;
  Ajustes.discapacidadesAplicadas.value = clave;

  final p = perfilDe(discapacidades);
  Ajustes.sinVoz.value = p.sinVoz;
  Ajustes.pantallaEsBoton.value = p.pantallaEsBoton;
  final escala = p.escalaTexto;
  if (escala != null && Ajustes.escalaTexto.value < escala) {
    Ajustes.escalaTexto.value = escala;
  }
  if (p.queMeHable) Ajustes.queMeHable.value = true;
  if (p.conSenas) Ajustes.conSenas.value = true;
  if (p.altoContraste) Ajustes.altoContraste.value = true;
  if (p.avisoVibracion) Ajustes.avisoVibracion.value = true;
}

// Lo que el encargado eligió en "Pantalla de ..." se aplica una vez por cada
// cambio suyo. Después la persona puede ajustarlo en "Aa" y se respeta.
void aplicarApariencia(Apariencia? a) {
  final cuando = a?.actualizado;
  if (a == null || cuando == null) return;
  final clave = '${cuando.millisecondsSinceEpoch}';
  if (clave == Ajustes.aparienciaAplicada.value) return;
  Ajustes.aparienciaAplicada.value = clave;
  Ajustes.escalaTexto.value = a.escalaTexto;
  Ajustes.altoContraste.value = a.altoContraste;
  Ajustes.queMeHable.value = a.queMeHable;
  Ajustes.menosMovimiento.value = a.menosMovimiento;
  Ajustes.oyeNana.value = a.oyeNana;
  Ajustes.sinVoz.value = a.contestarTocando;
  Ajustes.velocidadVoz.value = a.velocidadVoz;
}
