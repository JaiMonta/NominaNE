import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/repo.dart';
import 'empleados_page.dart' show money, usd;
import 'recalcular_nomina_dialog.dart';
import 'tasa_selector_dialog.dart';

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
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _NuevaNomina());
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
          },
          onUpdated: (n) => setState(() {
                _sel = n;
                _f = Repo.nominas();
              }));
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
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty)
            return const Center(child: Text('Aún no hay nóminas'));
          return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final n in s.data!)
                  ListTile(
                    title: Text('${n.nombre} '
                        '(${n.modalidad == 'contratado' ? 'Contratados · ${n.frecuencia}' : n.frecuencia})'),
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
  String nombre = '', frecuencia = 'quincenal', modalidad = 'normal';
  DateTime? ini, fin;
  double utilidades = 0;
  double? _tasaAuto;
  double? _tasaSel;
  DateTime? _tasaFechaSel;
  bool _busy = false;
  String? _err;

  double? get _tasaEfectiva => _tasaSel ?? _tasaAuto;
  DateTime? get _fechaTasaEfectiva => _tasaSel != null ? _tasaFechaSel : fin;

  Future<void> _cargarTasa() async {
    if (fin == null) return;
    final t = await Repo.tasa(fin!);
    if (mounted) setState(() => _tasaAuto = t);
  }

  Future<void> _elegirTasa() async {
    final r = await showDialog<({double tasa, DateTime fecha})>(
      context: context,
      builder: (_) => const TasaSelectorDialog(),
    );
    if (r != null) {
      setState(() {
        _tasaSel = r.tasa;
        _tasaFechaSel = r.fecha;
      });
    }
  }

  void _usarTasaAutomatica() {
    setState(() {
      _tasaSel = null;
      _tasaFechaSel = null;
    });
  }

  Future<DateTime?> _pick() => showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100));

  Future<void> _generar() async {
    if (nombre.trim().isEmpty ||
        ini == null ||
        fin == null ||
        fin!.isBefore(ini!)) {
      setState(() => _err = 'Complete nombre y un período válido');
      return;
    }
    if (_tasaEfectiva == null) {
      setState(() => _err =
          'No hay tasa BCV. Seleccione una tasa o regístrela en "Tasas".');
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
          utilidadesDias: utilidades,
          modalidad: modalidad,
          tasaOverride: _tasaSel,
          tasaFecha: _tasaFechaSel);
      if (!mounted) return;
      if (n == 0) {
        setState(() {
          _err = 'No hay empleados activos con modalidad '
              '${modalidad == 'contratado' ? 'Contratado' : 'Normal'} '
              'y frecuencia $frecuencia';
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
          width: anchoDialogo(context, 420),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                decoration: InputDecoration(
                    labelText: modalidad == 'contratado'
                        ? 'Nombre (ej. Contratados octubre)'
                        : 'Nombre (ej. 1ra quincena octubre)'),
                onChanged: (v) => nombre = v),
            DropdownButtonFormField<String>(
              initialValue: modalidad,
              decoration: const InputDecoration(labelText: 'Tipo de nómina'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(
                    value: 'contratado', child: Text('Contratados')),
              ],
              onChanged: (v) => setState(() {
                modalidad = v ?? 'normal';
                if (modalidad == 'contratado') utilidades = 0;
              }),
            ),
            DropdownButtonFormField<String>(
              value: frecuencia,
              decoration: const InputDecoration(
                  labelText: 'Frecuencia (Art. 150 LOT)'),
              items: const [
                DropdownMenuItem(value: 'semanal', child: Text('semanal')),
                DropdownMenuItem(value: 'quincenal', child: Text('quincenal')),
                DropdownMenuItem(value: 'mensual', child: Text('mensual')),
              ],
              onChanged: (v) => setState(() => frecuencia = v!),
            ),
            if (modalidad == 'contratado')
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Solo sueldo, sin deducciones'),
                subtitle: Text('El sueldo se prorratea según la frecuencia.'),
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
            if (modalidad == 'normal')
              TextField(
                  decoration: const InputDecoration(
                      labelText:
                          'Días de utilidades a pagar en esta nómina (0 = ninguno)'),
                  onChanged: (v) =>
                      utilidades = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.currency_exchange),
              title: Text(_tasaEfectiva == null
                  ? 'Tasa BCV: no cargada'
                  : 'Tasa BCV: ${usd.format(_tasaEfectiva!)} Bs/USD'
                      '${_fechaTasaEfectiva == null ? '' : ' (${fecha(_fechaTasaEfectiva!)})'}'),
              subtitle: Text(_tasaSel != null
                  ? 'Tasa seleccionada manualmente'
                  : 'Tasa automática al cierre del período'),
              trailing: TextButton(
                onPressed: _busy ? null : _elegirTasa,
                child: const Text('Elegir tasa'),
              ),
            ),
            if (_tasaSel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _usarTasaAutomatica,
                  child: const Text('Usar tasa automática'),
                ),
              ),
            if (_err != null)
              Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator()),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _busy ? null : _generar,
              child: const Text('Calcular')),
        ],
      );
}

class _NominaDetalle extends StatefulWidget {
  final Nomina nomina;
  final bool puedeEditar;
  final VoidCallback onBack;
  final void Function(Nomina) onUpdated;
  const _NominaDetalle(
      {required this.nomina,
      required this.puedeEditar,
      required this.onBack,
      required this.onUpdated});
  @override
  State<_NominaDetalle> createState() => _NominaDetalleState();
}

class _NominaDetalleState extends State<_NominaDetalle> {
  late Future<List<Recibo>> _f = Repo.recibos(widget.nomina.id);
  late String estado = widget.nomina.estado;

  Future<void> _estado(String e) async {
    if (e == 'aprobada') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Aprobar nómina'),
          content: const Text(
              'Se aprobará la nómina y las novedades no recurrentes incluidas '
              'dejarán de aparecer como pendientes. Las recurrentes se '
              'conservan.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aprobar')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        final eliminadas = await Repo.aprobarNomina(widget.nomina.id);
        if (!mounted) return;
        setState(() => estado = 'aprobada');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(eliminadas > 0
                ? 'Nómina aprobada. Se aplicaron $eliminadas novedades no recurrentes.'
                : 'Nómina aprobada.')));
      } catch (x) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo aprobar: $x')));
      }
      return;
    }
    await Repo.cambiarEstado(widget.nomina.id, e);
    setState(() => estado = e);
  }

  @override
  void didUpdateWidget(covariant _NominaDetalle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nomina.id != widget.nomina.id ||
        oldWidget.nomina.tasaBcv != widget.nomina.tasaBcv) {
      _f = Repo.recibos(widget.nomina.id);
    }
  }

  Future<void> _recalcular() async {
    final opciones = await showDialog<({double tasa, DateTime fecha})>(
      context: context,
      builder: (_) => RecalcularNominaDialog(nomina: widget.nomina),
    );
    if (opciones == null) return;

    try {
      await Repo.recalcularNomina(
          widget.nomina.id, opciones.tasa, opciones.fecha);
      final lista = await Repo.nominas();
      final actual = lista.firstWhere((x) => x.id == widget.nomina.id,
          orElse: () => widget.nomina);
      widget.onUpdated(actual);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Nómina recalculada con tasa ${opciones.tasa.toStringAsFixed(4)} Bs/USD.')));
      }
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo recalcular: $x')));
      }
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar nómina'),
        content: Text(
            estado == 'aprobada'
                ? 'Se eliminará la nómina aprobada y sus recibos. '
                    'Las novedades no recurrentes que estén aplicadas a esta nómina volverán a estar disponibles.'
                : 'Se eliminará la nómina y sus recibos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Repo.borrarNomina(widget.nomina.id);
      widget.onBack();
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $x')));
      }
    }
  }

  Future<void> _historial() async {
    try {
      final lista = await Repo.recalculosNomina(widget.nomina.id);
      if (!mounted) return;

      final items = <Widget>[];
      for (final r in lista) {
        final anterior = double.tryParse('${r['tasa_anterior']}') ?? 0;
        final nueva = double.tryParse('${r['tasa_nueva']}') ?? 0;
        final fechaAnterior = '${r['fecha_anterior'] ?? '—'}';
        final fechaNueva = '${r['fecha_nueva'] ?? '—'}';
        final rawCreado = r['created_at'];
        final creado = rawCreado == null
            ? ''
            : ' · ${fecha(DateTime.parse('$rawCreado').toLocal())}';
        items.add(ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
              '${money.format(anterior)} → ${money.format(nueva)} Bs/USD'),
          subtitle: Text('$fechaAnterior → $fechaNueva$creado'),
        ));
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Historial de recálculos'),
          content: SizedBox(
            width: anchoDialogo(context, 420),
            child: items.isEmpty
                ? const Text('Esta nómina no tiene recálculos.')
                : ListView(shrinkWrap: true, children: items),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cargar el historial: $x')));
      }
    }
  }

  Future<void> _pdfRecibo(Recibo r, List<Map<String, dynamic>> det) async {
    try {
      final empresa = await Repo.ajuste('empresa_nombre');
      final rif = await Repo.ajuste('empresa_rif');
      await emitirReciboPdf(
          nomina: widget.nomina,
          recibo: r,
          detalle: det,
          empresa: empresa,
          rif: rif);
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
    final opciones = await showDialog<({HojaNomina hoja, int recibos})>(
      context: context,
      builder: (ctx) {
        var hoja = HojaNomina.a4;
        var recibos = 4;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('PDF de nómina'),
            content: SizedBox(
              width: anchoDialogo(context, 380),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<HojaNomina>(
                  initialValue: hoja,
                  decoration:
                      const InputDecoration(labelText: 'Tamaño de hoja'),
                  items: const [
                    DropdownMenuItem(value: HojaNomina.a4, child: Text('A4')),
                    DropdownMenuItem(
                        value: HojaNomina.carta, child: Text('Carta')),
                    DropdownMenuItem(
                        value: HojaNomina.oficio, child: Text('Oficio')),
                  ],
                  onChanged: (v) =>
                      setLocal(() => hoja = v ?? HojaNomina.a4),
                ),
                DropdownButtonFormField<int>(
                  initialValue: recibos,
                  decoration:
                      const InputDecoration(labelText: 'Recibos por hoja'),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 6, child: Text('6')),
                  ],
                  onChanged: (v) => setLocal(() => recibos = v ?? 4),
                ),
                const SizedBox(height: 8),
                Text('Para 5 o 6 recibos se recomienda Oficio.',
                    style: Theme.of(ctx).textTheme.bodySmall),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, (hoja: hoja, recibos: recibos)),
                child: const Text('Generar PDF'),
              ),
            ],
          ),
        );
      },
    );
    if (opciones == null) return;

    try {
      final recibos = await Repo.recibos(widget.nomina.id);
      final items = <ReciboPdfData>[];
      for (final r in recibos) {
        items.add(ReciboPdfData(r, await Repo.detalle(r.id)));
      }
      final empresa = await Repo.ajuste('empresa_nombre');
      final rif = await Repo.ajuste('empresa_rif');
      await emitirNominaPdf(
          nomina: widget.nomina,
          items: items,
          empresa: empresa,
          rif: rif,
          hoja: opciones.hoja,
          recibosPorPagina: opciones.recibos);
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al generar PDF: $x')));
      }
    }
  }

  bool _esIngresoExtra(Map<String, dynamic> d) =>
      d['tipo'] == 'ingreso' && d['es_salarial'] == false;

  double _suma(List<Map<String, dynamic>> ds, String key) =>
      ds.fold<double>(0, (s, d) => s + ((d[key] ?? 0) as num).toDouble());

  Future<void> _ver(Recibo r) async {
    final det = await Repo.detalle(r.id);
    final base = det.where((d) => !_esIngresoExtra(d)).toList();
    final extras = det.where(_esIngresoExtra).toList();
    final ingresoSalarialBs =
        _suma(base.where((d) => d['tipo'] == 'ingreso').toList(), 'monto');
    final ingresoSalarialUsd =
        _suma(base.where((d) => d['tipo'] == 'ingreso').toList(), 'monto_usd');
    final extraBs = _suma(extras, 'monto');
    final extraUsd = _suma(extras, 'monto_usd');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Recibo · ${r.nombreEmpleado} (${r.cedula})'),
        content: SizedBox(
          width: anchoDialogo(context, 640),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Tasa BCV: ${r.tasaBcv == null ? '—' : '${usd.format(r.tasaBcv!)} Bs/USD'}'),
                ),
                if (esMovil(context)) ...[
                  for (final d in base) _conceptoCard(d),
                  _ingresoExtraCard(extras),
                  const SizedBox(height: 8),
                  _totalesCard(r, ingresoSalarialBs, ingresoSalarialUsd,
                      extraBs, extraUsd),
                ] else ...[
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
                      for (final d in base)
                        DataRow(cells: [
                          DataCell(Tooltip(
                              message: d['base_legal'] ?? '',
                              child: Text(d['concepto_nombre']))),
                          DataCell(Text('${d['cantidad']}')),
                          DataCell(Text(d['tipo'] == 'ingreso'
                              ? money.format(d['monto'])
                              : '')),
                          DataCell(Text(d['tipo'] == 'egreso'
                              ? money.format(d['monto'])
                              : '')),
                          DataCell(Text(d['tipo'] == 'ingreso'
                              ? usd.format(d['monto_usd'] ?? 0)
                              : '')),
                          DataCell(Text(d['tipo'] == 'egreso'
                              ? usd.format(d['monto_usd'] ?? 0)
                              : '')),
                        ]),
                    ]),
                  ),
                  _ingresoExtraCard(extras),
                  _totalesCard(r, ingresoSalarialBs, ingresoSalarialUsd,
                      extraBs, extraUsd),
                ],
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
                      Text('INCES: ${money.format(r.aporteInce)} Bs'),
                      Text('Pensiones: ${money.format(r.aportePension)} Bs'),
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _conceptoCard(Map<String, dynamic> d) {
    final ing = d['tipo'] == 'ingreso';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Text(d['concepto_nombre'] ?? ''),
        subtitle: Text('Cant: ${d['cantidad']}'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${ing ? '+' : '-'} ${money.format(d['monto'])} Bs',
                style: TextStyle(
                    color: ing ? Paleta.ingreso : Paleta.egreso,
                    fontWeight: FontWeight.w600)),
            Text('US\$ ${usd.format(d['monto_usd'] ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(String label, String bs, String us, {bool bold = false}) {
    final estilo = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: estilo)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(bs, style: estilo),
          Text(us, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]),
    );
  }

  Widget _ingresoExtraCard(List<Map<String, dynamic>> extras) {
    if (extras.isEmpty) return const SizedBox.shrink();
    final totalBs = _suma(extras, 'monto');
    final totalUsd = _suma(extras, 'monto_usd');
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.add_card, size: 18),
            const SizedBox(width: 6),
            Text('Ingreso extra (no salarial)',
                style: Theme.of(context).textTheme.titleSmall),
          ]),
          const SizedBox(height: 4),
          for (final d in extras)
            _filaResumen(
                '${d['concepto_nombre']} (cant. ${d['cantidad']})',
                '${money.format(d['monto'])} Bs',
                'US\$ ${usd.format(d['monto_usd'] ?? 0)}'),
          const Divider(),
          _filaResumen('Subtotal ingreso extra', '${money.format(totalBs)} Bs',
              'US\$ ${usd.format(totalUsd)}',
              bold: true),
        ]),
      ),
    );
  }

  Widget _totalesCard(Recibo r, double ingresoSalarialBs,
          double ingresoSalarialUsd, double extraBs, double extraUsd) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _filaResumen(
                'Ingresos salariales',
                '${money.format(ingresoSalarialBs)} Bs',
                'US\$ ${usd.format(ingresoSalarialUsd)}'),
            if (extraBs > 0)
              _filaResumen(
                  'Ingreso extra (no salarial)',
                  '${money.format(extraBs)} Bs',
                  'US\$ ${usd.format(extraUsd)}'),
            _filaResumen('Total ingresos', '${money.format(r.ingresos)} Bs',
                'US\$ ${usd.format(r.ingresosUsd)}'),
            _filaResumen('Egresos', '${money.format(r.egresos)} Bs',
                'US\$ ${usd.format(r.egresosUsd)}'),
            const Divider(),
            _filaResumen('NETO A PAGAR', '${money.format(r.neto)} Bs',
                'US\$ ${usd.format(r.netoUsd)}',
                bold: true),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.nomina;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${n.nombre} · ${fecha(n.inicio)} a ${fecha(n.fin)}'
                        '${n.modalidad == 'contratado' ? ' · Contratados' : ''}'
                        ' · ${n.frecuencia}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        'Tasa BCV: ${n.tasaBcv == null ? '—' : money.format(n.tasaBcv!)} Bs/USD'
                        '${n.tasaFecha == null ? '' : ' · ${fecha(n.tasaFecha!)}'}',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                        'Aportes patronales — IVSS ${money.format(n.totalAporteIvss)} · RPE ${money.format(n.totalAporteRpe)} · FAOV ${money.format(n.totalAporteFaov)} · LOPCYMAT ${money.format(n.totalAporteLopcymat)} · INCES ${money.format(n.totalAporteInce)} · Pensiones ${money.format(n.totalAportePension)}  (Total ${money.format(n.totalAportes)})',
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
              FilledButton(
                  onPressed: () => _estado('aprobada'),
                  child: const Text('Aprobar')),
              OutlinedButton(
                  onPressed: _eliminar, child: const Text('Eliminar')),
            ],
            if (widget.puedeEditar && estado == 'aprobada') ...[
              OutlinedButton.icon(
                  onPressed: _recalcular,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalcular')),
              TextButton.icon(
                  onPressed: _historial,
                  icon: const Icon(Icons.history),
                  label: const Text('Historial')),
              OutlinedButton(
                  onPressed: _eliminar, child: const Text('Eliminar')),
              FilledButton(
                  onPressed: () => _estado('pagada'),
                  child: const Text('Marcar pagada')),
            ],
          ]),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: FutureBuilder<List<Recibo>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              for (final r in s.data!)
                ListTile(
                  title: Text(r.nombreEmpleado),
                  isThreeLine: true,
                  subtitle: Text(
                      'Ingresos ${money.format(r.ingresos)} · Egresos ${money.format(r.egresos)}\n'
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
