import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../widgets/caritas_animo.dart';
import '../widgets/logo_nana.dart';
import 'dia.dart';
import 'semana.dart';
import 'tema.dart';

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

final _morado = _pdf(ColoresNana.morado);
final _moradoClaro = _pdf(ColoresNana.moradoClaro);
final _tinta = _pdf(ColoresNana.tinta);
final _tintaSuave = _pdf(ColoresNana.tintaSuave);
final _alerta = _pdf(ColoresNana.alerta);

// La letra del PDF (Helvetica) solo trae el alfabeto latino: á, ñ, ¿, ¡ sí;
// emojis y otros alfabetos no. Lo que no se puede dibujar se quita para que
// el reporte nunca truene por un nombre con un emoji.
String textoPdf(String s) {
  const cambios = {
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
    '–': '-',
    '—': '-',
    '…': '...',
    '•': '·',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (cambios.containsKey(c)) {
      b.write(cambios[c]);
    } else if (r == 0x0A ||
        (r >= 0x20 && r <= 0x7E) ||
        (r >= 0xA1 && r <= 0xFF)) {
      b.write(c);
    }
  }
  return b.toString().replaceAll(RegExp(' {2,}'), ' ').trim();
}

// 'NANA_semana_Rosa_2026-11-12.pdf'
String nombreReporte(String adulto, DateTime fecha) {
  final quien = textoPdf(adulto).replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]+'), '_');
  String dos(int n) => n.toString().padLeft(2, '0');
  return 'NANA_semana_${quien}_'
      '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)}.pdf';
}

Future<Uint8List?> _logo() async {
  try {
    final datos = await rootBundle.load(LogoNana.archivo);
    return datos.buffer.asUint8List();
  } catch (_) {
    return null; // sin logo el reporte sale igual
  }
}

String _medicinas(DiaSemana d) =>
    d.posibles == 0 ? 'Sin medicinas' : '${d.tomas} de ${d.posibles}';
String _animo(DiaSemana d) =>
    d.animo == null ? 'Sin dato' : CaritasAnimo.etiquetas[d.animo!];
String _movimiento(DiaSemana d) => d.movimientoPosible == 0
    ? '-'
    : '${d.movimiento} de ${d.movimientoPosible}';

// El reporte de la semana para mandarlo a la familia: lo importante, una
// tabla por día y el detalle de lo que se anotó. Solo datos, sin consejos.
Future<Uint8List> reporteSemanaPdf(
  String adulto,
  List<DiaSemana> dias, {
  DateTime? generado,
}) async {
  final quien = textoPdf(adulto);
  final t = TotalesSemana(dias);
  final logo = await _logo();
  final hecho = generado ?? DateTime.now();

  pw.Widget titulo(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      s,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: _morado,
      ),
    ),
  );

  pw.Widget punto(String s, {PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 5,
          height: 5,
          margin: const pw.EdgeInsets.only(top: 5, right: 8),
          decoration: pw.BoxDecoration(
            color: color ?? _morado,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(child: pw.Text(textoPdf(s))),
      ],
    ),
  );

  final sinDatos =
      t.tomas == 0 && dias.every((d) => d.animo == null && d.movimiento == 0);

  final doc = pw.Document(title: 'Reporte semanal de $quien', author: 'NANA');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 44),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ).copyWith(defaultTextStyle: pw.TextStyle(fontSize: 11.5, color: _tinta)),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _moradoClaro)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                avisoAlcance,
                style: pw.TextStyle(fontSize: 9, color: _tintaSuave),
              ),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _tintaSuave),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Image(pw.MemoryImage(logo), width: 58, height: 58),
              pw.SizedBox(width: 14),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Reporte semanal de $quien',
                    style: pw.TextStyle(
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                      color: _morado,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    rangoSemana(dias),
                    style: const pw.TextStyle(fontSize: 13),
                  ),
                  pw.Text(
                    'Generado el ${fechaLarga(hecho)} a las ${horaDe(hecho)}',
                    style: pw.TextStyle(fontSize: 10, color: _tintaSuave),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: _morado),

        titulo('Lo importante'),
        if (sinDatos) punto('Todavía no hay datos de esta semana.'),
        if (t.posibles == 0)
          punto('Medicinas: no tiene medicinas registradas.')
        else
          punto(
            'Medicinas a tiempo: ${t.tomas} de ${t.posibles}. '
            '${t.faltas.isEmpty ? 'Todas a tiempo.' : 'Faltaron el ${t.faltas.join(', el ')}.'}',
            color: t.faltas.isEmpty ? null : _alerta,
          ),
        if (t.mal.isEmpty)
          punto('Ningún día dijo sentirse mal.')
        else
          for (final d in t.mal)
            punto(
              'El ${d.nombre} dijo que se sentía mal, a las ${horaDe(d.horaMal!)}.',
              color: _alerta,
            ),
        if (t.movimientoPosible > 0)
          punto(
            'Se movió ${t.movimiento} de ${t.movimientoPosible} veces, '
            'según sus rutinas de actividad.',
          ),

        titulo('Día por día'),
        pw.TableHelper.fromTextArray(
          headers: ['Día', 'Medicinas', 'Ánimo', 'Movimiento'],
          data: [
            for (final d in dias)
              [tituloDia(d), _medicinas(d), _animo(d), _movimiento(d)],
          ],
          border: pw.TableBorder.all(color: _moradoClaro, width: 0.8),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: _morado),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          columnWidths: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.2),
          },
        ),

        titulo('Detalle de cada día'),
        for (final d in dias) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              tituloDia(d),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (d.registros.isEmpty)
            pw.Text(
              'Ese día no se anotó nada.',
              style: pw.TextStyle(color: _tintaSuave),
            ),
          for (final r in d.registros)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 74,
                    child: pw.Text(
                      horaDe(r.fecha),
                      style: pw.TextStyle(color: _tintaSuave),
                    ),
                  ),
                  pw.Expanded(child: pw.Text(textoPdf(queHizo(r)))),
                ],
              ),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}
