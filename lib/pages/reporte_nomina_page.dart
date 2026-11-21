import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/periodo_nomina.dart';
import '../core/theme.dart';
import '../services/reporte_nomina_csv.dart';
import '../services/reporte_nomina_pdf_service.dart';
import '../services/reporte_nomina_service.dart';

final _money = NumberFormat('#,##0.00', 'es');
final _fecha = DateFormat('dd/MM/yyyy');

Widget _stat(BuildContext context, String label, String value, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Text(label),
      ]),
    );

class ReporteNominaPage extends StatefulWidget {
  const ReporteNominaPage({super.key});

  @override
  State<ReporteNominaPage> createState() => _ReporteNominaPageState();
}

class _ReporteNominaPageState extends State<ReporteNominaPage> {
  TipoPeriodoNomina _tipo = TipoPeriodoNomina.mensual;
  DateTime _referencia = DateTime.now();
  late Future<ReporteNomina> _f = _cargar();

  RangoNomina get _rango => rangoNomina(_tipo, _referencia);

  Future<ReporteNomina> _cargar() =>
      ReporteNominaService.cargar(tipo: _tipo, referencia: _referencia);

  String _nombreTipo(TipoPeriodoNomina t) {
    switch (t) {
      case TipoPeriodoNomina.semanal:
        return 'Semanal';
      case TipoPeriodoNomina.mensual:
        return 'Mensual';
      case TipoPeriodoNomina.trimestral:
        return 'Trimestral';
      case TipoPeriodoNomina.semestral:
        return 'Semestral';
      case TipoPeriodoNomina.anual:
        return 'Anual';
    }
  }

  void _cambiarTipo(TipoPeriodoNomina t) {
    setState(() {
      _tipo = t;
      _f = _cargar();
    });
  }

  void _anterior() {
    final actual = _rango;
    setState(() {
      _referencia = actual.inicio.subtract(const Duration(days: 1));
      _f = _cargar();
    });
  }

  void _siguiente() {
    final actual = _rango;
    setState(() {
      _referencia = actual.fin.add(const Duration(days: 1));
      _f = _cargar();
    });
  }

  void _actual() {
    setState(() {
      _referencia = DateTime.now();
      _f = _cargar();
    });
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _referencia,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() {
        _referencia = d;
        _f = _cargar();
      });
    }
  }

  Future<void> _pdf(ReporteNomina r) async {
    try {
      await emitirReporteNominaPdf(r);
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF: $x')),
        );
      }
    }
  }

  void _csv(ReporteNomina r) {
    final csv = construirCsvReporte(r);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
          'download',
          'reporte_nomina_${DateFormat('yyyy_MM_dd').format(r.inicio)}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV generado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReporteNomina>(
      future: _f,
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = s.data!;
        final empleados = r.nominas
            .expand((n) => n.recibos)
            .map((x) => x.recibo.empleadoId)
            .toSet()
            .length;
        final ingresos = r.nominas.fold<double>(
            0, (s, n) => s + n.nomina.totalIngresos);
        final egresos = r.nominas.fold<double>(
            0, (s, n) => s + n.nomina.totalEgresos);
        final neto =
            r.nominas.fold<double>(0, (s, n) => s + n.nomina.totalNeto);
        final aportes = r.nominas.fold<double>(
            0, (s, n) => s + n.nomina.totalAportes);
        final ince = r.nominas.fold<double>(
            0, (s, n) => s + n.nomina.totalAporteInce);
        final pension = r.nominas.fold<double>(
            0, (s, n) => s + n.nomina.totalAportePension);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in TipoPeriodoNomina.values)
                ChoiceChip(
                  label: Text(_nombreTipo(t)),
                  selected: _tipo == t,
                  onSelected: (_) => _cambiarTipo(t),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(
                tooltip: 'Período anterior',
                onPressed: _anterior,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(r.etiqueta, textAlign: TextAlign.center),
                ),
              ),
              IconButton(
                tooltip: 'Período siguiente',
                onPressed: _siguiente,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Período actual',
                onPressed: _actual,
                icon: const Icon(Icons.today),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _stat(context, 'Nóminas', '${r.nominas.length}',
                  Theme.of(context).colorScheme.primary),
              _stat(context, 'Empleados', '$empleados', Paleta.ingreso),
              _stat(context, 'Ingresos', _money.format(ingresos),
                  Theme.of(context).colorScheme.primary),
              _stat(context, 'Egresos', _money.format(egresos), Colors.orange),
              _stat(context, 'Neto', _money.format(neto), Paleta.ingreso),
              _stat(context, 'Aportes', _money.format(aportes), Colors.orange),
              _stat(context, 'INCES', _money.format(ince), Colors.orange),
              _stat(context, 'Pensiones', _money.format(pension), Colors.orange),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _pdf(r),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF detallado'),
              ),
              OutlinedButton.icon(
                onPressed: () => _csv(r),
                icon: const Icon(Icons.table_view),
                label: const Text('Exportar CSV'),
              ),
            ]),
            const SizedBox(height: 8),
            if (r.nominas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text(
                        'No hay nóminas aprobadas o pagadas en el período.')),
              ),
            for (final n in r.nominas)
              Card(
                child: ListTile(
                  isThreeLine: true,
                  title: Text(n.nomina.nombre),
                  subtitle: Text(
                      '${_fecha.format(n.nomina.inicio)} a ${_fecha.format(n.nomina.fin)}'
                      ' · ${n.nomina.frecuencia} · ${n.nomina.modalidad}'
                      ' · ${n.nomina.estado}\n'
                      'Ingresos ${_money.format(n.nomina.totalIngresos)} · '
                      'Egresos ${_money.format(n.nomina.totalEgresos)} · '
                      'Neto ${_money.format(n.nomina.totalNeto)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('INCES',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(_money.format(n.nomina.totalAporteInce),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
