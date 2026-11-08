import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'reporte_nomina_service.dart';

final _money = NumberFormat('#,##0.00', 'es');
final _fecha = DateFormat('dd/MM/yyyy');

double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

Future<Uint8List> buildReporteNominaPdf(ReporteNomina reporte) async {
  final doc = pw.Document();
  final totalIngresos = reporte.nominas.fold<double>(
      0, (s, n) => s + n.nomina.totalIngresos);
  final totalEgresos = reporte.nominas.fold<double>(
      0, (s, n) => s + n.nomina.totalEgresos);
  final totalNeto =
      reporte.nominas.fold<double>(0, (s, n) => s + n.nomina.totalNeto);
  final totalAportes =
      reporte.nominas.fold<double>(0, (s, n) => s + n.nomina.totalAportes);
  final totalInce = reporte.nominas.fold<double>(
      0, (s, n) => s + n.nomina.totalAporteInce);

  final resumenNomina = <List<dynamic>>[];
  final resumenAportes = <List<dynamic>>[];
  final detalle = <List<dynamic>>[];

  for (final nomina in reporte.nominas) {
    final n = nomina.nomina;
    final periodo = '${_fecha.format(n.inicio)} a ${_fecha.format(n.fin)}';
    resumenNomina.add([
      n.nombre,
      periodo,
      '${n.frecuencia} · ${n.modalidad}',
      '${nomina.recibos.length}',
      _money.format(n.totalIngresos),
      _money.format(n.totalEgresos),
      _money.format(n.totalNeto),
    ]);
    resumenAportes.add([
      n.nombre,
      _money.format(n.totalAporteIvss),
      _money.format(n.totalAporteRpe),
      _money.format(n.totalAporteFaov),
      _money.format(n.totalAporteLopcymat),
      _money.format(n.totalAporteInce),
      _money.format(n.totalAportes),
    ]);

    for (final item in nomina.recibos) {
      final r = item.recibo;
      for (final d in item.detalle) {
        detalle.add([
          n.nombre,
          periodo,
          r.nombreEmpleado,
          r.cedula,
          (d['concepto_codigo'] ?? '').toString(),
          (d['concepto_nombre'] ?? '').toString(),
          (d['tipo'] ?? '').toString(),
          (d['cantidad'] ?? '').toString(),
          _money.format(_num(d['monto'])),
          _money.format(_num(d['monto_usd'])),
          (d['es_salarial'] == true ? 'Sí' : 'No'),
          (d['base_legal'] ?? '').toString(),
        ]);
      }

      final tasa = r.tasaBcv ?? n.tasaBcv;
      void patrono(String concepto, double monto) {
        detalle.add([
          n.nombre,
          periodo,
          r.nombreEmpleado,
          r.cedula,
          '',
          concepto,
          'patrono',
          '',
          _money.format(monto),
          tasa == null || tasa <= 0 ? '' : _money.format(monto / tasa),
          '',
          '',
        ]);
      }

      patrono('IVSS patronal', r.aporteIvss);
      patrono('RPE patronal', r.aporteRpe);
      patrono('FAOV patronal', r.aporteFaov);
      patrono('LOPCYMAT patronal', r.aporteLopcymat);
      patrono('INCES patronal', r.aporteInce);
    }
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => [
      pw.Text(
        reporte.empresa.trim().isEmpty ? 'Nómina' : reporte.empresa,
        style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      if (reporte.rif.trim().isNotEmpty)
        pw.Text('RIF: ${reporte.rif}', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 6),
      pw.Text(
        'Reporte de nómina · ${reporte.etiqueta}',
        style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        'Del ${_fecha.format(reporte.inicio)} al ${_fecha.format(reporte.fin)}'
        '  ·  Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      pw.SizedBox(height: 12),
      pw.Text('Resumen por nómina',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Nómina',
          'Período',
          'Frecuencia · modalidad',
          'Empleados',
          'Ingresos',
          'Egresos',
          'Neto',
        ],
        data: resumenNomina,
        headerStyle: const pw.TextStyle(fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.centerLeft,
      ),
      pw.SizedBox(height: 10),
      pw.Text('Aportes patronales por nómina',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Nómina',
          'IVSS',
          'RPE',
          'FAOV',
          'LOPCYMAT',
          'INCES',
          'Total',
        ],
        data: resumenAportes,
        headerStyle: const pw.TextStyle(fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.centerLeft,
      ),
      pw.SizedBox(height: 10),
      pw.Text('Detalle de todos los ítems',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (detalle.isEmpty)
        pw.Text('No hay nóminas aprobadas o pagadas en el período.')
      else
        pw.TableHelper.fromTextArray(
          headers: const [
            'Nómina',
            'Período',
            'Empleado',
            'Cédula',
            'Código',
            'Concepto',
            'Tipo',
            'Cantidad',
            'Monto Bs',
            'Monto US\$',
            'Salarial',
            'Base legal',
          ],
          data: detalle,
          headerStyle: const pw.TextStyle(fontSize: 7),
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Totales: ingresos ${_money.format(totalIngresos)} · '
        'egresos ${_money.format(totalEgresos)} · '
        'neto ${_money.format(totalNeto)} · '
        'aportes patronales ${_money.format(totalAportes)} · '
        'INCES ${_money.format(totalInce)}',
        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
    ],
  ));

  return doc.save();
}

Future<void> emitirReporteNominaPdf(ReporteNomina reporte) async {
  final bytes = await buildReporteNominaPdf(reporte);
  final slug = DateFormat('yyyy_MM_dd').format(reporte.inicio);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'reporte_nomina_$slug.pdf',
  );
}
