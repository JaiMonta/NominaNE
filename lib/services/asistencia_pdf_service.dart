import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResumenAsistencia {
  final String empleado;
  final String cedula;
  final String departamento;
  final int dias;
  final double horas;
  final int pendientes;

  const ResumenAsistencia({
    required this.empleado,
    required this.cedula,
    required this.departamento,
    required this.dias,
    required this.horas,
    required this.pendientes,
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
          'Total horas: ${totalHoras.toStringAsFixed(2)}',
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
