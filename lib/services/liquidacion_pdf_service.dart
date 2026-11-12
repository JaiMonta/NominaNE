import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/liquidacion_models.dart';
import '../models/models.dart';

final _money = NumberFormat('#,##0.00', 'es');
final _usd = NumberFormat('#,##0.00', 'en');

String _f(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _slug(String s) => s
    .trim()
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

Future<Uint8List> buildLiquidacionPdf({
  required Liquidacion liquidacion,
  required List<LiquidacionDetalle> detalle,
  required Empleado empleado,
  required String empresa,
  String rif = '',
}) async {
  final doc = pw.Document();
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  final small = const pw.TextStyle(fontSize: 8);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(30),
    build: (_) => [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(empresa.isEmpty ? 'NÓMINA' : empresa,
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              if (rif.isNotEmpty) pw.Text('RIF: $rif'),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('LIQUIDACIÓN DE TRABAJADOR',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha de cálculo: ${_f(liquidacion.fechaCalculo)}'),
              pw.Text('Tasa BCV: ${liquidacion.tasaBcv?.toStringAsFixed(4) ?? '—'}'),
            ],
          ),
        ],
      ),
      pw.Divider(),
      pw.SizedBox(height: 4),
      pw.TableHelper.fromTextArray(
        cellStyle: small,
        headerStyle: bold,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        headers: ['Trabajador', 'Cédula', 'Cargo', 'Ingreso', 'Egreso', 'Motivo'],
        data: [
          [
            empleado.nombreCompleto,
            empleado.cedula,
            empleado.cargo ?? '',
            _f(liquidacion.fechaIngreso),
            _f(liquidacion.fechaEgreso),
            liquidacion.motivoLabel,
          ]
        ],
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        cellStyle: small,
        headerStyle: bold,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        headers: [
          'Salario normal Bs',
          'Salario integral diario Bs',
          'Años',
          'Meses',
          'Días',
        ],
        data: [
          [
            _money.format(liquidacion.salarioNormalBs),
            _money.format(liquidacion.salarioIntegralBs),
            '${liquidacion.anios}',
            '${liquidacion.meses}',
            '${liquidacion.dias}',
          ]
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text('Prestaciones sociales', style: bold),
      pw.TableHelper.fromTextArray(
        cellStyle: small,
        headerStyle: bold,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        headers: ['Garantía', 'Intereses', 'Retroactivo', 'Se paga'],
        data: [
          [
            _money.format(liquidacion.garantiaBs),
            _money.format(liquidacion.interesesBs),
            _money.format(liquidacion.retroactivoBs),
            _money.format(liquidacion.prestacionesBs),
          ]
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text('Conceptos', style: bold),
      pw.TableHelper.fromTextArray(
        cellStyle: small,
        headerStyle: bold,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        headers: ['Concepto', 'Días', 'Base', 'Monto Bs', 'Base legal'],
        data: [
          for (final d in detalle)
            [
              d.nombre,
              d.dias == 0 ? '' : d.dias.toStringAsFixed(2),
              d.base == 0 ? '' : _money.format(d.base),
              _money.format(d.monto),
              d.baseLegal ?? '',
            ]
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Total ingresos: Bs ${_money.format(liquidacion.netoBs + liquidacion.deduccionesBs)}'),
              pw.Text('Deducciones: Bs ${_money.format(liquidacion.deduccionesBs)}'),
              pw.Text('Neto a pagar: Bs ${_money.format(liquidacion.netoBs)}',
                  style: bold),
              pw.Text('Neto en USD: \$ ${_usd.format(liquidacion.totalUsd)}',
                  style: bold),
            ],
          )
        ],
      ),
      pw.SizedBox(height: 22),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(children: [
            pw.Container(width: 190, height: 1, color: PdfColors.grey700),
            pw.SizedBox(height: 3),
            pw.Text('Firma del trabajador', style: small),
          ]),
          pw.Column(children: [
            pw.Container(width: 190, height: 1, color: PdfColors.grey700),
            pw.SizedBox(height: 3),
            pw.Text('Firma del patrono', style: small),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Prestaciones sociales conforme a la LOTTT Art. 142. Intereses Art. 143. '
        'Vacaciones Arts. 190, 195 y 196. Bono vacacional Art. 192. '
        'Utilidades Arts. 131 y 134. La liquidación debe pagarse dentro de los '
        'cinco días siguientes a la terminación de la relación laboral.',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
      ),
    ],
  ));
  return doc.save();
}

Future<void> emitirLiquidacionPdf({
  required Liquidacion liquidacion,
  required List<LiquidacionDetalle> detalle,
  required Empleado empleado,
  required String empresa,
  String rif = '',
}) async {
  final bytes = await buildLiquidacionPdf(
    liquidacion: liquidacion,
    detalle: detalle,
    empleado: empleado,
    empresa: empresa,
    rif: rif,
  );
  await Printing.sharePdf(
    bytes: bytes,
    filename:
        'liquidacion_${_slug(empleado.nombreCompleto)}_${_slug(_f(liquidacion.fechaEgreso))}.pdf',
  );
}
