import 'reporte_nomina_service.dart';
import 'repo.dart';

String construirCsvReporte(ReporteNomina reporte) {
  final rows = <List<String>>[
    [
      'Nómina',
      'Período',
      'Frecuencia',
      'Modalidad',
      'Estado',
      'Empleado',
      'Cédula',
      'Código',
      'Concepto',
      'Tipo',
      'Cantidad',
      'Monto Bs',
      'Monto US\$',
      'Base legal',
      'Salarial',
    ]
  ];

  for (final nomina in reporte.nominas) {
    final n = nomina.nomina;
    final periodo = '${fecha(n.inicio)} a ${fecha(n.fin)}';
    for (final item in nomina.recibos) {
      final r = item.recibo;
      final tasa = r.tasaBcv ?? n.tasaBcv;

      for (final d in item.detalle) {
        rows.add([
          n.nombre,
          periodo,
          n.frecuencia,
          n.modalidad,
          n.estado,
          r.nombreEmpleado,
          r.cedula,
          (d['concepto_codigo'] ?? '').toString(),
          (d['concepto_nombre'] ?? '').toString(),
          (d['tipo'] ?? '').toString(),
          (d['cantidad'] ?? '').toString(),
          (d['monto'] ?? '').toString(),
          (d['monto_usd'] ?? '').toString(),
          (d['base_legal'] ?? '').toString(),
          d['es_salarial'] == true ? 'Sí' : 'No',
        ]);
      }

      void patrono(String concepto, double monto) {
        rows.add([
          n.nombre,
          periodo,
          n.frecuencia,
          n.modalidad,
          n.estado,
          r.nombreEmpleado,
          r.cedula,
          '',
          concepto,
          'patrono',
          '',
          monto.toStringAsFixed(2),
          tasa == null || tasa <= 0
              ? ''
              : (monto / tasa).toStringAsFixed(2),
          '',
          '',
        ]);
      }

      patrono('IVSS patronal', r.aporteIvss);
      patrono('RPE patronal', r.aporteRpe);
      patrono('FAOV patronal', r.aporteFaov);
      patrono('LOPCYMAT patronal', r.aporteLopcymat);
      patrono('INCES patronal', r.aporteInce);
      patrono('Pensiones patronal', r.aportePension);
    }
  }

  return rows
      .map((row) => row.map((value) => '"${value.replaceAll('"', '""')}"').join(';'))
      .join('\r\n');
}
