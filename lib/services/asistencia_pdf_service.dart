import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ResumenAsistencia {
  final String empleado;
  final String cedula;
  final String departamento;
  final int dias;
  final double horas;
  final int pendientes;
  final int retardos;
  final int minutosRetardo;

  const ResumenAsistencia({
    required this.empleado,
    required this.cedula,
    required this.departamento,
    required this.dias,
    required this.horas,
    required this.pendientes,
    required this.retardos,
    required this.minutosRetardo,
  });
}

Future<void> emitirAsistenciaPeriodo({
  required String empresa,
  required String titulo,
  required DateTime inicio,
  required DateTime fin,
  required List<ResumenAsistencia> filas,
  required String nombreArchivo,
}) async {
  final doc = pw.Document();
  final totalHoras = filas.fold<double>(0, (s, f) => s + f.horas);
  final totalRetardos = filas.fold<int>(0, (s, f) => s + f.retardos);
  final totalMinutos =
      filas.fold<int>(0, (s, f) => s + f.minutosRetardo);
  final subtitulo =
      'Del ${DateFormat('dd/MM/yyyy').format(inicio)} al ${DateFormat('dd/MM/yyyy').format(fin)}';

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => [
      pw.Text(
        empresa,
        style: const pw.TextStyle(
            fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text('Control de asistencia · $titulo'),
      pw.Text(subtitulo, style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 14),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Empleado',
          'Cédula',
          'Departamento',
          'Días',
          'Horas',
          'Retardos',
          'Min. retardo',
          'Pendientes',
        ],
        data: [
          for (final f in filas)
            [
              f.empleado,
              f.cedula,
              f.departamento,
              '${f.dias}',
              f.horas.toStringAsFixed(2),
              '${f.retardos}',
              '${f.minutosRetardo}',
              '${f.pendientes}',
            ],
        ],
        headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.centerLeft,
        cellStyle: const pw.TextStyle(fontSize: 9),
      ),
      pw.SizedBox(height: 10),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Total horas: ${totalHoras.toStringAsFixed(2)}  ·  '
          'Retardos: $totalRetardos  ·  Min. retardo: $totalMinutos',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ],
  ));

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: nombreArchivo,
  );
}

Future<void> imprimirQrAsistencia({
  required String empresa,
  required DateTime fecha,
  required String url,
}) async {
  final painter = QrPainter(
    data: url,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: ui.Color(0xFF000000),
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: ui.Color(0xFF000000),
    ),
  );
  final data =
      await painter.toImageData(1200, format: ui.ImageByteFormat.png);
  if (data == null) {
    throw StateError('No se pudo generar la imagen del QR');
  }
  final image = pw.MemoryImage(data.buffer.asUint8List());
  final doc = pw.Document();

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (_) => pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            empresa,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Control de asistencia · QR del día',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            DateFormat('dd/MM/yyyy').format(fecha),
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 20),
          pw.Image(image, width: 380, height: 380),
          pw.SizedBox(height: 16),
          pw.Text(
            'Escanee con la cámara del teléfono',
            style: const pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Ingrese su cédula y PIN para marcar entrada o salida.',
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            url,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  ));

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'qr_asistencia_${DateFormat('yyyy-MM-dd').format(fecha)}.pdf',
  );
}
