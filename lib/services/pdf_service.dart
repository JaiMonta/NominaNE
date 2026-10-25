import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

final _money = NumberFormat('#,##0.00', 'es');
final _usd = NumberFormat('#,##0.00', 'en');

String _f(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _slug(String s) => s
    .trim()
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// Recibo junto con su detalle (conceptos) para armar el PDF.
class ReciboPdfData {
  final Recibo recibo;
  final List<Map<String, dynamic>> detalle;
  ReciboPdfData(this.recibo, this.detalle);
}

Future<Uint8List> buildReciboPdf({
  required Nomina nomina,
  required Recibo recibo,
  required List<Map<String, dynamic>> detalle,
  required String empresa,
  String rif = '',
}) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => _reciboWidget(
        nomina: nomina,
        recibo: recibo,
        detalle: detalle,
        empresa: empresa,
        rif: rif),
  ));
  return doc.save();
}

Future<void> emitirReciboPdf({
  required Nomina nomina,
  required Recibo recibo,
  required List<Map<String, dynamic>> detalle,
  required String empresa,
  String rif = '',
}) async {
  final bytes = await buildReciboPdf(
      nomina: nomina,
      recibo: recibo,
      detalle: detalle,
      empresa: empresa,
      rif: rif);
  final quien = recibo.cedula.isEmpty ? recibo.nombreEmpleado : recibo.cedula;
  await Printing.sharePdf(
      bytes: bytes,
      filename: 'recibo_${_slug(quien)}_${_slug(_f(nomina.fin))}.pdf');
}

Future<Uint8List> buildNominaPdf({
  required Nomina nomina,
  required List<ReciboPdfData> items,
  required String empresa,
  String rif = '',
}) async {
  final doc = pw.Document();
  for (final it in items) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => _reciboWidget(
          nomina: nomina,
          recibo: it.recibo,
          detalle: it.detalle,
          empresa: empresa,
          rif: rif),
    ));
  }
  return doc.save();
}

Future<void> emitirNominaPdf({
  required Nomina nomina,
  required List<ReciboPdfData> items,
  required String empresa,
  String rif = '',
}) async {
  final bytes = await buildNominaPdf(
      nomina: nomina, items: items, empresa: empresa, rif: rif);
  await Printing.sharePdf(
      bytes: bytes,
      filename: 'nomina_${_slug(nomina.nombre)}_${_slug(_f(nomina.fin))}.pdf');
}

pw.Widget _reciboWidget({
  required Nomina nomina,
  required Recibo recibo,
  required List<Map<String, dynamic>> detalle,
  required String empresa,
  required String rif,
}) {
  const small = pw.TextStyle(fontSize: 8);
  const bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  const titulo = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
  final tasa = recibo.tasaBcv ?? nomina.tasaBcv;

  bool esIngresoExtra(Map<String, dynamic> d) =>
      d['tipo'] == 'ingreso' && d['es_salarial'] == false;
  double suma(List<Map<String, dynamic>> ds, String key) =>
      ds.fold<double>(0, (s, d) => s + ((d[key] ?? 0) as num).toDouble());

  final base = detalle.where((d) => !esIngresoExtra(d)).toList();
  final extras = detalle.where(esIngresoExtra).toList();
  final ingresoSalarialBs =
      suma(base.where((d) => d['tipo'] == 'ingreso').toList(), 'monto');
  final ingresoSalarialUsd =
      suma(base.where((d) => d['tipo'] == 'ingreso').toList(), 'monto_usd');
  final extraBs = suma(extras, 'monto');
  final extraUsd = suma(extras, 'monto_usd');

  final rows = <List<String>>[];
  for (final d in base) {
    final ing = d['tipo'] == 'ingreso';
    final monto = _money.format((d['monto'] ?? 0) as num);
    final montoUsd = _usd.format((d['monto_usd'] ?? 0) as num);
    rows.add([
      '${d['concepto_nombre']}',
      '${d['cantidad']}',
      ing ? monto : '',
      ing ? '' : monto,
      ing ? montoUsd : '',
      ing ? '' : montoUsd,
    ]);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(empresa.trim().isEmpty ? 'RECIBO DE PAGO' : empresa,
                style: titulo),
            if (rif.trim().isNotEmpty) pw.Text('RIF: $rif', style: small),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('RECIBO DE PAGO',
                style: const pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Emitido: ${_f(DateTime.now())}', style: small),
          ]),
        ],
      ),
      pw.Divider(),
      pw.Text(
          'Nómina: ${nomina.nombre}  ·  Período: ${_f(nomina.inicio)} a ${_f(nomina.fin)}',
          style: bold),
      pw.Text(
          'Frecuencia: ${nomina.frecuencia}'
          '${tasa != null ? '  ·  Tasa BCV: ${_usd.format(tasa)} Bs/USD' : ''}',
          style: small),
      pw.SizedBox(height: 6),
      pw.Text('Empleado: ${recibo.nombreEmpleado}', style: bold),
      pw.Text('Cédula: ${recibo.cedula}', style: small),
      pw.Text(
          'Salario mensual: US\$ ${_usd.format(recibo.salarioMensualUsd)}'
          '${tasa != null ? '  ·  ${_money.format(recibo.salarioMensualUsd * tasa)} Bs' : ''}',
          style: small),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Concepto',
          'Cant.',
          'Ingreso (Bs)',
          'Egreso (Bs)',
          'Ingreso (US\$)',
          'Egreso (US\$)',
        ],
        data: rows,
        headerStyle:
            const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        cellStyle: small,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: const {
          1: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FlexColumnWidth(1.6),
          4: pw.FlexColumnWidth(1.6),
          5: pw.FlexColumnWidth(1.6),
        },
      ),
      if (extras.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text('Ingreso extra (no salarial)', style: bold),
        pw.SizedBox(height: 3),
        pw.TableHelper.fromTextArray(
          headers: const ['Concepto', 'Cant.', 'Monto (Bs)', 'Monto (US\$)'],
          data: [
            for (final d in extras)
              [
                '${d['concepto_nombre']}',
                '${d['cantidad']}',
                _money.format((d['monto'] ?? 0) as num),
                _usd.format((d['monto_usd'] ?? 0) as num),
              ],
          ],
          headerStyle:
              const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: small,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
          cellAlignments: const {
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1.6),
          },
        ),
        pw.SizedBox(height: 3),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
              'Subtotal ingreso extra: ${_money.format(extraBs)} Bs (US\$ ${_usd.format(extraUsd)})',
              style: bold),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(
                'Ingresos salariales: ${_money.format(ingresoSalarialBs)} Bs (US\$ ${_usd.format(ingresoSalarialUsd)})',
                style: small),
            if (extraBs > 0)
              pw.Text(
                  'Ingreso extra (no salarial): ${_money.format(extraBs)} Bs (US\$ ${_usd.format(extraUsd)})',
                  style: small),
            pw.Text(
                'Total ingresos: ${_money.format(recibo.ingresos)} Bs (US\$ ${_usd.format(recibo.ingresosUsd)})',
                style: small),
            pw.Text(
                'Total egresos: ${_money.format(recibo.egresos)} Bs (US\$ ${_usd.format(recibo.egresosUsd)})',
                style: small),
            pw.Text(
                'NETO A PAGAR: ${_money.format(recibo.neto)} Bs (US\$ ${_usd.format(recibo.netoUsd)})',
                style: const pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Aportes patronales (empresa):', style: bold),
            pw.Text(
                'IVSS: ${_money.format(recibo.aporteIvss)} Bs   ·   RPE: ${_money.format(recibo.aporteRpe)} Bs',
                style: small),
            pw.Text(
                'FAOV: ${_money.format(recibo.aporteFaov)} Bs   ·   LOPCYMAT: ${_money.format(recibo.aporteLopcymat)} Bs',
                style: small),
            pw.Text('Total aportes: ${_money.format(recibo.aportes)} Bs',
                style: bold),
          ]),
        ],
      ),
      pw.SizedBox(height: 48),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        _firma('Recibí conforme'),
        _firma('Por la empresa'),
      ]),
      pw.SizedBox(height: 12),
      pw.Text(
          'Documento generado por el sistema de nómina. Base legal: LOT/LOTTT y LOPCYMAT. '
          'Verifique los montos y parámetros vigentes.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
    ],
  );
}

pw.Widget _firma(String label) => pw.Column(
      children: [
        pw.Container(
          width: 170,
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.8))),
        ),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
