import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/repo.dart';
import 'empleados_page.dart' show money, usd;

class NominasPage extends StatefulWidget {
  final bool puedeEditar;
  const NominasPage({super.key, required this.puedeEditar});
  @override
  State<NominasPage> createState() => _NominasPageState();
}

class _NominasPageState extends State<NominasPage> {
  late Future<List<Nomina>> _f = Repo.nominas();
  Nomina? _sel;
  void _reload() => setState(() => _f = Repo.nominas());

  Future<void> _nueva() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _NuevaNomina());
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_sel != null) {
      return _NominaDetalle(
          nomina: _sel!,
          puedeEditar: widget.puedeEditar,
          onBack: () {
            setState(() => _sel = null);
            _reload();
          });
    }
    return Scaffold(
      floatingActionButton: widget.puedeEditar
          ? FloatingActionButton.extended(
              onPressed: _nueva,
              icon: const Icon(Icons.calculate),
              label: const Text('Generar nómina'))
          : null,
      body: FutureBuilder<List<Nomina>>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const Center(child: Text('Aún no hay nóminas'));
          return ListView(children: [
            for (final n in s.data!)
              ListTile(
                title: Text('${n.nombre} (${n.frecuencia})'),
                subtitle: Text('${fecha(n.inicio)} a ${fecha(n.fin)} · '
                    'Ingresos ${money.format(n.totalIngresos)} · '
                    'Egresos ${money.format(n.totalEgresos)} · '
                    'Neto ${money.format(n.totalNeto)}'
                    '${n.tasaBcv != null ? ' (US\$ ${usd.format(n.totalNeto / n.tasaBcv!)})' : ''}'),
                trailing: Chip(label: Text(n.estado)),
                onTap: () => setState(() => _sel = n),
              ),
          ]);
        },
      ),
    );
  }
}

class _NuevaNomina extends StatefulWidget {
  const _NuevaNomina();
  @override
  State<_NuevaNomina> createState() => _NuevaNominaState();
}

class _NuevaNominaState extends State<_NuevaNomina> {
  String nombre = '', frecuencia = 'quincenal';
  DateTime? ini, fin;
  double utilidades = 0;
  double? _tasa;
  bool _busy = false;
  String? _err;

  Future<void> _cargarTasa() async {
    if (fin == null) return;
    final t = await Repo.tasa(fin!);
    if (mounted) setState(() => _tasa = t);
  }

  Future<DateTime?> _pick() => showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100));

  Future<void> _generar() async {
    if (nombre.trim().isEmpty || ini == null || fin == null || fin!.isBefore(ini!)) {
      setState(() => _err = 'Complete nombre y un período válido');
      return;
    }
    if (_tasa == null) {
      setState(() => _err =
          'No hay tasa BCV cargada para el cierre del período. Regístrela en "Tasas".');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final n = await Repo.generarNomina(
          nombre: nombre.trim(),
          frecuencia: frecuencia,
          inicio: ini!,
          fin: fin!,
          utilidadesDias: utilidades);
      if (!mounted) return;
      if (n == 0) {
        setState(() {
          _err = 'No hay empleados activos con esa frecuencia de pago';
          _busy = false;
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (x) {
      setState(() {
        _err = '$x';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Generar nómina'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                decoration: const InputDecoration(labelText: 'Nombre (ej. 1ra quincena octubre)'),
                onChanged: (v) => nombre = v),
            DropdownButtonFormField<String>(
              value: frecuencia,
              decoration: const InputDecoration(labelText: 'Frecuencia (Art. 150 LOT)'),
              items: const [
                DropdownMenuItem(value: 'semanal', child: Text('semanal')),
                DropdownMenuItem(value: 'quincenal', child: Text('quincenal')),
                DropdownMenuItem(value: 'mensual', child: Text('mensual')),
              ],
              onChanged: (v) => setState(() => frecuencia = v!),
            ),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Desde: ${ini == null ? '—' : fecha(ini!)}'),
                onTap: () async {
                  final d = await _pick();
                  if (d != null) setState(() => ini = d);
                }),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Hasta: ${fin == null ? '—' : fecha(fin!)}'),
                onTap: () async {
                  final d = await _pick();
                  if (d != null) {
                    setState(() => fin = d);
                    await _cargarTasa();
                  }
                }),
            TextField(
                decoration: const InputDecoration(
                    labelText: 'Días de utilidades a pagar en esta nómina (0 = ninguno)'),
                onChanged: (v) => utilidades = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.currency_exchange),
              title: Text(_tasa == null
                  ? 'Tasa BCV: no cargada para el cierre'
                  : 'Tasa BCV aplicable: ${usd.format(_tasa!)} Bs/USD'),
              subtitle: _tasa == null
                  ? const Text('Regístrela en la pestaña "Tasas"')
                  : null,
            ),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ]),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _busy ? null : _generar, child: const Text('Calcular')),
        ],
      );
}

class _NominaDetalle extends StatefulWidget {
  final Nomina nomina;
  final bool puedeEditar;
  final VoidCallback onBack;
  const _NominaDetalle(
      {required this.nomina, required this.puedeEditar, required this.onBack});
  @override
  State<_NominaDetalle> createState() => _NominaDetalleState();
}

class _NominaDetalleState extends State<_NominaDetalle> {
  late Future<List<Recibo>> _f = Repo.recibos(widget.nomina.id);
  late String estado = widget.nomina.estado;

  Future<void> _estado(String e) async {
    await Repo.cambiarEstado(widget.nomina.id, e);
    setState(() => estado = e);
  }

  Future<void> _pdfRecibo(Recibo r, List<Map<String, dynamic>> det) async {
    try {
      final empresa = await Repo.ajuste('empresa_nombre');
      final rif = await Repo.ajuste('empresa_rif');
      await emitirReciboPdf(
          nomina: widget.nomina, recibo: r, detalle: det, empresa: empresa, rif: rif);
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al generar PDF: $x')));
      }
    }
  }

  Future<void> _pdfReciboPorId(Recibo r) async {
    final det = await Repo.detalle(r.id);
    await _pdfRecibo(r, det);
  }

  Future<void> _pdfNomina() async {
    try {
      final recibos = await Repo.recibos(widget.nomina.id);
      final items = <ReciboPdfData>[];
      for (final r in recibos) {
        items.add(ReciboPdfData(r, await Repo.detalle(r.id)));
      }
      final empresa = await Repo.ajuste('empresa_nombre');
      final rif = await Repo.ajuste('empresa_rif');
      await emitirNominaPdf(
          nomina: widget.nomina, items: items, empresa: empresa, rif: rif);
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al generar PDF: $x')));
      }
    }
  }

  Future<void> _ver(Recibo r) async {
    final det = await Repo.detalle(r.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Recibo · ${r.nombreEmpleado} (${r.cedula})'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Tasa BCV: ${r.tasaBcv == null ? '—' : '${usd.format(r.tasaBcv!)} Bs/USD'}'),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(columns: const [
                    DataColumn(label: Text('Concepto')),
                    DataColumn(label: Text('Cant.'), numeric: true),
                    DataColumn(label: Text('Ingreso (Bs)'), numeric: true),
                    DataColumn(label: Text('Egreso (Bs)'), numeric: true),
                    DataColumn(label: Text('Ingreso (US\$)'), numeric: true),
                    DataColumn(label: Text('Egreso (US\$)'), numeric: true),
                  ], rows: [
                    for (final d in det)
                      DataRow(cells: [
                        DataCell(Tooltip(
                            message: d['base_legal'] ?? '', child: Text(d['concepto_nombre']))),
                        DataCell(Text('${d['cantidad']}')),
                        DataCell(Text(d['tipo'] == 'ingreso' ? money.format(d['monto']) : '')),
                        DataCell(Text(d['tipo'] == 'egreso' ? money.format(d['monto']) : '')),
                        DataCell(Text(d['tipo'] == 'ingreso' ? usd.format(d['monto_usd'] ?? 0) : '')),
                        DataCell(Text(d['tipo'] == 'egreso' ? usd.format(d['monto_usd'] ?? 0) : '')),
                      ]),
                    DataRow(cells: [
                      const DataCell(Text('NETO A PAGAR', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataCell(Text('')),
                      DataCell(Text(money.format(r.ingresos))),
                      DataCell(Text('${money.format(r.egresos)}  =  ${money.format(r.neto)}')),
                      DataCell(Text(usd.format(r.ingresosUsd))),
                      DataCell(Text('${usd.format(r.egresosUsd)}  =  ${usd.format(r.netoUsd)}')),
                    ]),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aportes patronales (empresa)',
                          style: Theme.of(context).textTheme.titleSmall),
                      Text('IVSS: ${money.format(r.aporteIvss)} Bs'),
                      Text('RPE: ${money.format(r.aporteRpe)} Bs'),
                      Text('FAOV: ${money.format(r.aporteFaov)} Bs'),
                      Text('LOPCYMAT: ${money.format(r.aporteLopcymat)} Bs'),
                      Text('Total: ${money.format(r.aportes)} Bs',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _pdfRecibo(r, det),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nomina;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${n.nombre} · ${fecha(n.inicio)} a ${fecha(n.fin)}',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Aportes patronales — IVSS ${money.format(n.totalAporteIvss)} · RPE ${money.format(n.totalAporteRpe)} · FAOV ${money.format(n.totalAporteFaov)} · LOPCYMAT ${money.format(n.totalAporteLopcymat)}  (Total ${money.format(n.totalAportes)})',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Chip(label: Text(estado)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _pdfNomina,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF nómina')),
            if (widget.puedeEditar && estado == 'borrador') ...[
              FilledButton(onPressed: () => _estado('aprobada'), child: const Text('Aprobar')),
              OutlinedButton(
                  onPressed: () async {
                    await Repo.borrarNomina(n.id);
                    widget.onBack();
                  },
                  child: const Text('Eliminar')),
            ],
            if (widget.puedeEditar && estado == 'aprobada')
              FilledButton(onPressed: () => _estado('pagada'), child: const Text('Marcar pagada')),
          ]),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: FutureBuilder<List<Recibo>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              for (final r in s.data!)
                ListTile(
                  title: Text(r.nombreEmpleado),
                  isThreeLine: true,
                  subtitle: Text('Ingresos ${money.format(r.ingresos)} · Egresos ${money.format(r.egresos)}\n'
                      'Neto ${money.format(r.neto)} Bs · US\$ ${usd.format(r.netoUsd)}'),
                  trailing: IconButton(
                      tooltip: 'PDF del recibo',
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: () => _pdfReciboPorId(r)),
                  onTap: () => _ver(r),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}
