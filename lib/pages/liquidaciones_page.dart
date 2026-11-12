import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/liquidacion_engine.dart';
import '../core/responsive.dart';
import '../models/liquidacion_models.dart';
import '../models/models.dart';
import '../services/liquidacion_pdf_service.dart';
import '../services/liquidacion_repo.dart';
import '../services/repo.dart';

final _f = DateFormat('dd/MM/yyyy');
final _m = NumberFormat('#,##0.00', 'es');

String _fmt(double v) => _m.format(v);

class LiquidacionesPage extends StatelessWidget {
  final bool puedeEditar;
  const LiquidacionesPage({super.key, required this.puedeEditar});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.receipt_long), text: 'Liquidar'),
                  Tab(icon: Icon(Icons.savings), text: 'Prestaciones'),
                  Tab(icon: Icon(Icons.beach_access), text: 'Vacaciones'),
                  Tab(icon: Icon(Icons.percent), text: 'Tasas de interés'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _LiquidarTab(puedeEditar: puedeEditar),
                  _PrestacionesTab(puedeEditar: puedeEditar),
                  _VacacionesTab(puedeEditar: puedeEditar),
                  _TasasTab(puedeEditar: puedeEditar),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LiquidarTab extends StatefulWidget {
  final bool puedeEditar;
  const _LiquidarTab({required this.puedeEditar});
  @override
  State<_LiquidarTab> createState() => _LiquidarTabState();
}

class _LiquidarTabState extends State<_LiquidarTab> {
  late Future<List<Empleado>> _emps = Repo.empleados();
  late Future<List<Liquidacion>> _liqs = LiquidacionRepo.liquidaciones();

  void _reload() => setState(() {
        _emps = Repo.empleados();
        _liqs = LiquidacionRepo.liquidaciones();
      });

  Future<void> _nueva() async {
    final emps = await _emps;
    if (!mounted) return;
    final ok = await showDialog<bool>(
        context: context,
        useSafeArea: true,
        builder: (_) => _LiquidacionForm(empleados: emps));
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Empleado>>(
        future: _emps,
        builder: (context, es) {
          if (!es.hasData) {
            return es.hasError
                ? Center(child: Text('Error: ${es.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          final empleados = es.data!;
          return FutureBuilder<List<Liquidacion>>(
            future: _liqs,
            builder: (context, ls) {
              if (!ls.hasData) {
                return ls.hasError
                    ? Center(child: Text('Error: ${ls.error}'))
                    : const Center(child: CircularProgressIndicator());
              }
              final liquidaciones = ls.data!;
              return Stack(
                children: [
                  if (liquidaciones.isEmpty)
                    const Center(
                        child: Text('Sin liquidaciones registradas'))
                  else
                    ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 90),
                      itemCount: liquidaciones.length,
                      itemBuilder: (_, i) {
                        final l = liquidaciones[i];
                        final e = empleados.firstWhere(
                            (x) => x.id == l.empleadoId,
                            orElse: () => Empleado());
                        return Card(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(l.estado == 'pagada'
                                  ? Icons.check
                                  : l.estado == 'aprobada'
                                      ? Icons.verified
                                      : Icons.edit),
                            ),
                            title: Text(e.nombreCompleto.isEmpty
                                ? 'Trabajador'
                                : e.nombreCompleto),
                            subtitle: Text(
                                '${l.motivoLabel} · ${_f.format(l.fechaEgreso)}\n'
                                'Prestaciones: Bs ${_fmt(l.prestacionesBs)} · Neto: Bs ${_fmt(l.netoBs)}'),
                            isThreeLine: true,
                            trailing: Chip(label: Text(l.estado)),
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                  context: context,
                                  useSafeArea: true,
                                  builder: (_) => _DetalleLiquidacionDialog(
                                      liquidacion: l,
                                      empleado: e,
                                      puedeEditar: widget.puedeEditar));
                              if (ok == true) _reload();
                            },
                          ),
                        );
                      },
                    ),
                  if (widget.puedeEditar)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.extended(
                        onPressed: _nueva,
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva liquidación'),
                      ),
                    ),
                ],
              );
            },
          );
        },
      );
}

class _DetalleLiquidacionDialog extends StatefulWidget {
  final Liquidacion liquidacion;
  final Empleado empleado;
  final bool puedeEditar;
  const _DetalleLiquidacionDialog({
    required this.liquidacion,
    required this.empleado,
    required this.puedeEditar,
  });
  @override
  State<_DetalleLiquidacionDialog> createState() =>
      _DetalleLiquidacionDialogState();
}

class _DetalleLiquidacionDialogState extends State<_DetalleLiquidacionDialog> {
  late final Future<List<LiquidacionDetalle>> _detalle =
      LiquidacionRepo.detalle(widget.liquidacion.id!);
  late final Future<String> _empresa = LiquidacionRepo.empresa();
  late final Future<String> _rif = LiquidacionRepo.rif();
  bool _busy = false;

  Future<void> _pdf() async {
    try {
      final d = await _detalle;
      final empresa = await _empresa;
      final rif = await _rif;
      await emitirLiquidacionPdf(
          liquidacion: widget.liquidacion,
          detalle: d,
          empleado: widget.empleado,
          empresa: empresa,
          rif: rif);
    } catch (e) {
      _snack('No se pudo generar el PDF: $e');
    }
  }

  Future<void> _accion(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('$e');
      }
    }
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.liquidacion;
    final e = widget.empleado;
    return AlertDialog(
      title: Text('Liquidación · ${e.nombreCompleto}'),
      content: SizedBox(
        width: anchoDialogo(context, 780),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l.motivoLabel} · ${_f.format(l.fechaEgreso)}'),
              const Divider(),
              Text('Salario normal: Bs ${_fmt(l.salarioNormalBs)}'),
              Text('Salario integral: Bs ${_fmt(l.salarioIntegralBs)}'),
              Text('Garantía: Bs ${_fmt(l.garantiaBs)} · '
                  'Intereses: Bs ${_fmt(l.interesesBs)}'),
              Text('Retroactivo: Bs ${_fmt(l.retroactivoBs)} · '
                  'Prestaciones: Bs ${_fmt(l.prestacionesBs)}'),
              const Divider(),
              FutureBuilder<List<LiquidacionDetalle>>(
                future: _detalle,
                builder: (context, s) {
                  if (!s.hasData) return const LinearProgressIndicator();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 14,
                      headingRowHeight: 32,
                      dataRowMinHeight: 28,
                      dataRowMaxHeight: 40,
                      columns: const [
                        DataColumn(label: Text('Concepto')),
                        DataColumn(label: Text('Días')),
                        DataColumn(label: Text('Monto')),
                      ],
                      rows: [
                        for (final d in s.data!)
                          DataRow(cells: [
                            DataCell(Text(d.nombre)),
                            DataCell(Text(d.dias == 0
                                ? ''
                                : d.dias.toStringAsFixed(2))),
                            DataCell(Text('Bs ${_fmt(d.monto)}')),
                          ])
                      ],
                    ),
                  );
                },
              ),
              const Divider(),
              Text('Neto a pagar: Bs ${_fmt(l.netoBs)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Neto en USD: \$ ${_fmt(l.totalUsd)}'),
              if (l.nota != null && l.nota!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nota: ${l.nota}'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : _pdf, child: const Text('PDF')),
        if (widget.puedeEditar && l.estado == 'borrador')
          TextButton(
              onPressed: _busy
                  ? null
                  : () => _accion(
                      () => LiquidacionRepo.eliminar(l.id!)),
              child: const Text('Eliminar')),
        if (widget.puedeEditar && l.estado == 'borrador')
          FilledButton(
              onPressed: _busy
                  ? null
                  : () => _accion(
                      () => LiquidacionRepo.aprobar(l.id!)),
              child: const Text('Aprobar')),
        if (widget.puedeEditar && l.estado == 'aprobada')
          TextButton(
              onPressed: _busy
                  ? null
                  : () => _accion(
                      () => LiquidacionRepo.anular(l.id!)),
              child: const Text('Anular')),
        if (widget.puedeEditar && l.estado == 'aprobada')
          FilledButton(
              onPressed: _busy
                  ? null
                  : () => _accion(
                      () => LiquidacionRepo.pagar(l.id!)),
              child: const Text('Marcar pagada')),
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    );
  }
}

class _PrestacionesData {
  final PrestacionesConfig config;
  final List<PrestacionesMovimiento> movimientos;
  final List<TasaInteresPrestaciones> tasas;
  final double saldo;
  final double intereses;
  _PrestacionesData(this.config, this.movimientos, this.tasas,
      this.saldo, this.intereses);
}

class _PrestacionesTab extends StatefulWidget {
  final bool puedeEditar;
  const _PrestacionesTab({required this.puedeEditar});
  @override
  State<_PrestacionesTab> createState() => _PrestacionesTabState();
}

class _PrestacionesTabState extends State<_PrestacionesTab> {
  late Future<List<Empleado>> _emps = Repo.empleados();
  String? _empleadoId;
  Future<_PrestacionesData>? _data;

  Future<_PrestacionesData> _load(String id) async {
    final empleados = await _emps;
    final e = empleados.firstWhere((x) => x.id == id);
    final config = await LiquidacionRepo.config(id, e.fechaIngreso);
    final movs = await LiquidacionRepo.movimientos(id);
    final tasas = await LiquidacionRepo.tasas();
    final saldo = movs
        .where((m) => m.tipo != 'interes')
        .fold<double>(0, (s, m) => s + m.monto);
    final intereses = movs
        .where((m) => m.tipo == 'interes')
        .fold<double>(0, (s, m) => s + m.monto);
    return _PrestacionesData(config, movs, tasas, saldo, intereses);
  }

  void _select(String? id) {
    if (id == null) return;
    setState(() {
      _empleadoId = id;
      _data = _load(id);
    });
  }

  void _reload() {
    if (_empleadoId != null) {
      setState(() => _data = _load(_empleadoId!));
    }
  }

  Future<void> _guardarConfig(PrestacionesConfig c) async {
    await LiquidacionRepo.guardarConfig(c);
    _reload();
  }

  Future<void> _movimiento(PrestacionesMovimiento? m) async {
    if (_empleadoId == null) return;
    final ok = await showDialog<bool>(
        context: context,
        useSafeArea: true,
        builder: (_) => _MovimientoDialog(
            empleadoId: _empleadoId!, movimiento: m));
    if (ok == true) _reload();
  }

  Future<void> _generarGarantia() async {
    if (_empleadoId == null) return;
    try {
      final n =
          await LiquidacionRepo.generarPrestaciones(_empleadoId!, DateTime.now());
      _snack(n == 0
          ? 'No se generaron movimientos nuevos (ya existen o no hay salario).'
          : 'Se generaron $n movimientos de prestaciones.');
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _generarIntereses(_PrestacionesData d) async {
    if (d.tasas.isEmpty) {
      _snack('Cargue primero las tasas de interés mensuales.');
      return;
    }
    final calc = await calcularInteresesPrestaciones(
        config: d.config,
        movimientos: d.movimientos,
        tasas: d.tasas,
        hasta: DateTime.now());
    if (calc.meses.isEmpty) {
      _snack('No hay base o tasas para calcular intereses.');
      return;
    }
    var creados = 0;
    for (final mes in calc.meses) {
      final periodo = mes['periodo'] as DateTime;
      final existe = d.movimientos.any((m) =>
          m.tipo == 'interes' &&
          m.periodo != null &&
          m.periodo!.year == periodo.year &&
          m.periodo!.month == periodo.month);
      if (existe) continue;
      final fecha = DateTime(periodo.year, periodo.month + 1, 0);
      await LiquidacionRepo.guardarMovimiento(PrestacionesMovimiento(
        empleadoId: _empleadoId!,
        fecha: fecha,
        periodo: periodo,
        tipo: 'interes',
        monto: (mes['interes'] as double),
        tasaInteres: (mes['tasa'] as double),
        modalidad: d.config.modalidad,
        nota: 'Interés calculado',
      ));
      creados++;
    }
    _snack(creados == 0
        ? 'Los intereses de esos meses ya estaban registrados.'
        : 'Se registraron $creados intereses mensuales.');
    _reload();
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Empleado>>(
        future: _emps,
        builder: (context, es) {
          if (!es.hasData) {
            return es.hasError
                ? Center(child: Text('Error: ${es.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          final empleados = es.data!;
          _empleadoId ??= empleados.isEmpty ? null : empleados.first.id;
          if (_empleadoId != null && _data == null) {
            _data = _load(_empleadoId!);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _empleadoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Trabajador',
                            border: OutlineInputBorder()),
                        items: [
                          for (final e in empleados)
                            DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                    '${e.nombreCompleto} · ${e.cedula}')),
                        ],
                        onChanged: _select,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Expanded(
                child: _data == null
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder<_PrestacionesData>(
                        future: _data,
                        builder: (context, s) {
                          if (!s.hasData) {
                            return s.hasError
                                ? Center(child: Text('Error: ${s.error}'))
                                : const Center(
                                    child: CircularProgressIndicator());
                          }
                          return _prestacionesBody(s.data!);
                        },
                      ),
              ),
            ],
          );
        },
      );

  Widget _prestacionesBody(_PrestacionesData d) {
    final c = d.config;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuración de la garantía',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        value: c.modalidad,
                        decoration:
                            const InputDecoration(labelText: 'Modalidad'),
                        items: const [
                          DropdownMenuItem(
                              value: 'contabilidad',
                              child: Text('Contabilidad')),
                          DropdownMenuItem(
                              value: 'fideicomiso',
                              child: Text('Fideicomiso')),
                          DropdownMenuItem(
                              value: 'fondo',
                              child: Text('Fondo Nacional')),
                          DropdownMenuItem(
                              value: 'no_depositada',
                              child: Text('No depositada')),
                        ],
                        onChanged: widget.puedeEditar
                            ? (v) {
                                c.modalidad = v ?? c.modalidad;
                                _guardarConfig(c);
                              }
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        value: c.tipoTasa,
                        decoration:
                            const InputDecoration(labelText: 'Tasa aplicable'),
                        items: const [
                          DropdownMenuItem(
                              value: 'pasiva', child: Text('Pasiva BCV')),
                          DropdownMenuItem(
                              value: 'promedio',
                              child: Text('Promedio activa/pasiva')),
                          DropdownMenuItem(
                              value: 'activa', child: Text('Activa BCV')),
                          DropdownMenuItem(
                              value: 'rendimiento',
                              child: Text('Rendimiento fideicomiso')),
                        ],
                        onChanged: widget.puedeEditar
                            ? (v) {
                                c.tipoTasa = v ?? c.tipoTasa;
                                _guardarConfig(c);
                              }
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Capitalizar intereses'),
                        value: c.capitalizarIntereses,
                        onChanged: widget.puedeEditar
                            ? (v) {
                                c.capitalizarIntereses = v;
                                _guardarConfig(c);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                            'Garantía: Bs ${_fmt(d.saldo)}\nIntereses registrados: Bs ${_fmt(d.intereses)}')))),
            const SizedBox(width: 8),
            if (widget.puedeEditar)
              FilledButton.icon(
                  onPressed: () => _movimiento(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Movimiento')),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.puedeEditar)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                  onPressed: _generarGarantia,
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Generar garantía')),
              OutlinedButton.icon(
                  onPressed: () => _generarIntereses(d),
                  icon: const Icon(Icons.calculate),
                  label: const Text('Generar intereses')),
            ],
          ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
            headingRowHeight: 32,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 52,
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Días')),
              DataColumn(label: Text('Monto')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final m in d.movimientos)
                DataRow(cells: [
                  DataCell(Text(_f.format(m.fecha))),
                  DataCell(Text(m.tipoLabel)),
                  DataCell(Text(m.dias == 0
                      ? ''
                      : m.dias.toStringAsFixed(2))),
                  DataCell(Text('Bs ${_fmt(m.monto)}')),
                  DataCell(widget.puedeEditar
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              onPressed: () => _movimiento(m),
                              icon: const Icon(Icons.edit, size: 18)),
                          IconButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                          title: const Text('Eliminar'),
                                          content: const Text(
                                              '¿Eliminar este movimiento?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('Cancelar')),
                                            FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, true),
                                                child: const Text('Eliminar')),
                                          ],
                                        ));
                                if (ok == true) {
                                  await LiquidacionRepo.eliminarMovimiento(
                                      m.id!);
                                  _reload();
                                }
                              },
                              icon: const Icon(Icons.delete, size: 18)),
                        ])
                      : const SizedBox()),
                ])
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MovimientoDialog extends StatefulWidget {
  final String empleadoId;
  final PrestacionesMovimiento? movimiento;
  const _MovimientoDialog({required this.empleadoId, this.movimiento});
  @override
  State<_MovimientoDialog> createState() => _MovimientoDialogState();
}

class _MovimientoDialogState extends State<_MovimientoDialog> {
  late String _tipo = widget.movimiento?.tipo ?? 'saldo_inicial';
  late DateTime _fecha = widget.movimiento?.fecha ?? DateTime.now();
  final _dias = TextEditingController();
  final _salario = TextEditingController();
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  String? _err;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    if (m != null) {
      _dias.text = m.dias == 0 ? '' : '${m.dias}';
      _salario.text = m.salarioIntegral == 0 ? '' : '${m.salarioIntegral}';
      _monto.text = '${m.monto.abs()}';
      _nota.text = m.nota ?? '';
    }
  }

  @override
  void dispose() {
    _dias.dispose();
    _salario.dispose();
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final dias = double.tryParse(_dias.text.replaceAll(',', '.')) ?? 0;
    final salario =
        double.tryParse(_salario.text.replaceAll(',', '.')) ?? 0;
    var monto = double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0;
    if ((_tipo == 'garantia_trimestral' || _tipo == 'dias_adicionales') &&
        dias > 0 &&
        salario > 0) {
      monto = dias * salario;
    }
    if (_tipo == 'anticipo' || _tipo == 'pago') monto = -monto.abs();
    if (monto == 0) {
      setState(() => _err = 'Indique un monto');
      return;
    }
    try {
      await LiquidacionRepo.guardarMovimiento(PrestacionesMovimiento(
        id: widget.movimiento?.id,
        empleadoId: widget.empleadoId,
        fecha: _fecha,
        periodo: widget.movimiento?.periodo ??
            ((_tipo == 'garantia_trimestral' ||
                    _tipo == 'dias_adicionales')
                ? _fecha
                : null),
        tipo: _tipo,
        dias: dias,
        salarioIntegral: salario,
        monto: monto,
        tasaInteres: widget.movimiento?.tasaInteres,
        modalidad: widget.movimiento?.modalidad,
        nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.movimiento == null
            ? 'Nuevo movimiento'
            : 'Editar movimiento'),
        content: SizedBox(
          width: anchoDialogo(context, 460),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                      value: 'saldo_inicial', child: Text('Saldo inicial')),
                  DropdownMenuItem(
                      value: 'garantia_trimestral',
                      child: Text('Garantía trimestral')),
                  DropdownMenuItem(
                      value: 'dias_adicionales',
                      child: Text('Días adicionales')),
                  DropdownMenuItem(
                      value: 'anticipo', child: Text('Anticipo')),
                  DropdownMenuItem(value: 'pago', child: Text('Pago')),
                  DropdownMenuItem(value: 'ajuste', child: Text('Ajuste')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Fecha: ${_f.format(_fecha)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
                  if (d != null) setState(() => _fecha = d);
                },
              ),
              TextField(
                controller: _dias,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Días (15 garantía, 2 adicionales)'),
              ),
              TextField(
                controller: _salario,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Salario integral diario'),
              ),
              TextField(
                controller: _monto,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Monto Bs (positivo; anticipo/pago se resta)'),
              ),
              TextField(
                controller: _nota,
                decoration: const InputDecoration(labelText: 'Nota'),
              ),
              if (_err != null)
                Text(_err!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}

class _VacacionesTab extends StatefulWidget {
  final bool puedeEditar;
  const _VacacionesTab({required this.puedeEditar});
  @override
  State<_VacacionesTab> createState() => _VacacionesTabState();
}

class _VacacionesTabState extends State<_VacacionesTab> {
  late Future<List<Empleado>> _emps = Repo.empleados();
  String? _empleadoId;
  Future<List<VacacionesPeriodo>>? _periodos;

  void _select(String? id) {
    if (id == null) return;
    setState(() {
      _empleadoId = id;
      _periodos = LiquidacionRepo.vacaciones(id);
    });
  }

  void _reload() {
    if (_empleadoId != null) {
      setState(() => _periodos = LiquidacionRepo.vacaciones(_empleadoId!));
    }
  }

  Future<void> _generar() async {
    if (_empleadoId == null) return;
    try {
      final n = await LiquidacionRepo.generarVacaciones(_empleadoId!);
      _snack('Períodos generados: $n');
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _editar(VacacionesPeriodo p) async {
    final ok = await showDialog<bool>(
        context: context,
        useSafeArea: true,
        builder: (_) => _VacacionDialog(periodo: p));
    if (ok == true) _reload();
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Empleado>>(
        future: _emps,
        builder: (context, es) {
          if (!es.hasData) {
            return es.hasError
                ? Center(child: Text('Error: ${es.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          final empleados = es.data!;
          _empleadoId ??= empleados.isEmpty ? null : empleados.first.id;
          if (_empleadoId != null && _periodos == null) {
            _periodos = LiquidacionRepo.vacaciones(_empleadoId!);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _empleadoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Trabajador',
                            border: OutlineInputBorder()),
                        items: [
                          for (final e in empleados)
                            DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                    '${e.nombreCompleto} · ${e.cedula}')),
                        ],
                        onChanged: _select,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.puedeEditar)
                      IconButton(
                          tooltip: 'Generar períodos',
                          onPressed: _generar,
                          icon: const Icon(Icons.autorenew)),
                  ],
                ),
              ),
              Expanded(
                child: _periodos == null
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder<List<VacacionesPeriodo>>(
                        future: _periodos,
                        builder: (context, s) {
                          if (!s.hasData) {
                            return s.hasError
                                ? Center(child: Text('Error: ${s.error}'))
                                : const Center(
                                    child: CircularProgressIndicator());
                          }
                          if (s.data!.isEmpty) {
                            return const Center(
                                child: Text(
                                    'Sin períodos. Use Generar períodos.'));
                          }
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            children: [
                              for (final p in s.data!)
                                Card(
                                  child: ListTile(
                                    title: Text(
                                        '${_f.format(p.periodoInicio)} - ${_f.format(p.periodoFin)}'),
                                    subtitle: Text(
                                        'Vacaciones: ${p.diasVacaciones} días · disfrutados ${p.diasDisfrutados} · pendientes ${p.pendienteVacaciones.toStringAsFixed(2)}\n'
                                        'Bono: ${p.diasBono} días · pagados ${p.diasBonoPagados} · pendientes ${p.pendienteBono.toStringAsFixed(2)}'),
                                    isThreeLine: true,
                                    trailing: widget.puedeEditar
                                        ? const Icon(Icons.edit)
                                        : null,
                                    onTap: widget.puedeEditar
                                        ? () => _editar(p)
                                        : null,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
}

class _VacacionDialog extends StatefulWidget {
  final VacacionesPeriodo periodo;
  const _VacacionDialog({required this.periodo});
  @override
  State<_VacacionDialog> createState() => _VacacionDialogState();
}

class _VacacionDialogState extends State<_VacacionDialog> {
  late final p = widget.periodo;
  late final _vac = TextEditingController(text: '${p.diasVacaciones}');
  late final _bono = TextEditingController(text: '${p.diasBono}');
  late final _dis = TextEditingController(text: '${p.diasDisfrutados}');
  late final _bonoPag =
      TextEditingController(text: '${p.diasBonoPagados}');
  late final _salario = TextEditingController(
      text: p.salarioNormal == 0 ? '' : '${p.salarioNormal}');
  late final _nota = TextEditingController(text: p.nota ?? '');
  String? _err;

  Future<void> _guardar() async {
    try {
      p.diasVacaciones =
          double.tryParse(_vac.text.replaceAll(',', '.')) ?? p.diasVacaciones;
      p.diasBono =
          double.tryParse(_bono.text.replaceAll(',', '.')) ?? p.diasBono;
      p.diasDisfrutados =
          double.tryParse(_dis.text.replaceAll(',', '.')) ?? 0;
      p.diasBonoPagados =
          double.tryParse(_bonoPag.text.replaceAll(',', '.')) ?? 0;
      p.salarioNormal =
          double.tryParse(_salario.text.replaceAll(',', '.')) ?? 0;
      p.nota = _nota.text.trim().isEmpty ? null : _nota.text.trim();
      await LiquidacionRepo.guardarVacacion(p);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Período vacacional'),
        content: SizedBox(
          width: anchoDialogo(context, 460),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '${_f.format(p.periodoInicio)} - ${_f.format(p.periodoFin)}'),
              TextField(
                  controller: _vac,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Días de vacaciones')),
              TextField(
                  controller: _dis,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Días disfrutados')),
              TextField(
                  controller: _bono,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Días de bono')),
              TextField(
                  controller: _bonoPag,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Días de bono pagados')),
              TextField(
                  controller: _salario,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Salario normal de referencia (Bs)')),
              TextField(
                  controller: _nota,
                  decoration: const InputDecoration(labelText: 'Nota')),
              if (_err != null)
                Text(_err!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}

class _TasasTab extends StatefulWidget {
  final bool puedeEditar;
  const _TasasTab({required this.puedeEditar});
  @override
  State<_TasasTab> createState() => _TasasTabState();
}

class _TasasTabState extends State<_TasasTab> {
  late Future<List<TasaInteresPrestaciones>> _tasas =
      LiquidacionRepo.tasas();

  void _reload() =>
      setState(() => _tasas = LiquidacionRepo.tasas());

  Future<void> _editar(TasaInteresPrestaciones? t) async {
    final ok = await showDialog<bool>(
        context: context,
        useSafeArea: true,
        builder: (_) => _TasaDialog(tasa: t));
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<TasaInteresPrestaciones>>(
        future: _tasas,
        builder: (context, s) {
          if (!s.hasData) {
            return s.hasError
                ? Center(child: Text('Error: ${s.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              if (s.data!.isEmpty)
                const Center(child: Text('Sin tasas cargadas'))
              else
                ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  children: [
                    for (final t in s.data!)
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(
                              '${t.periodo.year}-${t.periodo.month.toString().padLeft(2, '0')}'),
                          subtitle: Text(
                              'Activa ${(t.tasaActiva * 100).toStringAsFixed(2)}% · '
                              'Pasiva ${(t.tasaPasiva * 100).toStringAsFixed(2)}% · '
                              'Promedio ${(t.tasaPromedio * 100).toStringAsFixed(2)}% · '
                              'Fideicomiso ${(t.rendimientoFideicomiso * 100).toStringAsFixed(2)}%'),
                          isThreeLine: true,
                          trailing: widget.puedeEditar
                              ? const Icon(Icons.edit)
                              : null,
                          onTap: widget.puedeEditar
                              ? () => _editar(t)
                              : null,
                        ),
                      ),
                  ],
                ),
              if (widget.puedeEditar)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: () => _editar(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Tasa mensual'),
                  ),
                ),
            ],
          );
        },
      );
}

class _TasaDialog extends StatefulWidget {
  final TasaInteresPrestaciones? tasa;
  const _TasaDialog({this.tasa});
  @override
  State<_TasaDialog> createState() => _TasaDialogState();
}

class _TasaDialogState extends State<_TasaDialog> {
  late DateTime _periodo = widget.tasa?.periodo ?? DateTime.now();
  late final _activa = TextEditingController(
      text: widget.tasa == null
          ? ''
          : (widget.tasa!.tasaActiva * 100).toStringAsFixed(2));
  late final _pasiva = TextEditingController(
      text: widget.tasa == null
          ? ''
          : (widget.tasa!.tasaPasiva * 100).toStringAsFixed(2));
  late final _promedio = TextEditingController(
      text: widget.tasa == null
          ? ''
          : (widget.tasa!.tasaPromedio * 100).toStringAsFixed(2));
  late final _fideicomiso = TextEditingController(
      text: widget.tasa == null
          ? ''
          : (widget.tasa!.rendimientoFideicomiso * 100)
              .toStringAsFixed(2));
  String? _err;

  Future<void> _guardar() async {
    try {
      final t = TasaInteresPrestaciones(
        periodo: DateTime(_periodo.year, _periodo.month, 1),
        tasaActiva:
            (double.tryParse(_activa.text.replaceAll(',', '.')) ?? 0) / 100,
        tasaPasiva:
            (double.tryParse(_pasiva.text.replaceAll(',', '.')) ?? 0) / 100,
        tasaPromedio:
            (double.tryParse(_promedio.text.replaceAll(',', '.')) ?? 0) /
                100,
        rendimientoFideicomiso:
            (double.tryParse(_fideicomiso.text.replaceAll(',', '.')) ?? 0) /
                100,
      );
      await LiquidacionRepo.guardarTasa(t);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Tasa de interés mensual'),
        content: SizedBox(
          width: anchoDialogo(context, 460),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Período: ${_periodo.year}-${_periodo.month.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _periodo,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
                  if (d != null) {
                    setState(
                        () => _periodo = DateTime(d.year, d.month, 1));
                  }
                },
              ),
              TextField(
                  controller: _activa,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Tasa activa anual (%)')),
              TextField(
                  controller: _pasiva,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Tasa pasiva anual (%)')),
              TextField(
                  controller: _promedio,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Promedio activa/pasiva anual (%)')),
              TextField(
                  controller: _fideicomiso,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Rendimiento fideicomiso anual (%)')),
              if (_err != null)
                Text(_err!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}

class _LiquidacionForm extends StatefulWidget {
  final List<Empleado> empleados;
  const _LiquidacionForm({required this.empleados});
  @override
  State<_LiquidacionForm> createState() => _LiquidacionFormState();
}

class _LiquidacionFormState extends State<_LiquidacionForm> {
  late final Future<Map<String, double>> _paramsF = Repo.parametrosMapa();
  Map<String, double>? _params;
  Empleado? _empleado;
  DateTime _fechaEgreso = DateTime.now();
  String _motivo = MotivosEgreso.renuncia;
  double _tasa = 0;
  bool _cargando = false;
  bool _guardando = false;
  String? _err;
  double _saldoGarantia = 0;
  double _intereses = 0;
  double _vacTomadasPeriodo = 0;
  double _bonoPagadoPeriodo = 0;

  final _salario = TextEditingController();
  final _vacPend = TextEditingController(text: '0');
  final _bonoPend = TextEditingController(text: '0');
  final _utilidadesDias = TextEditingController(text: '30');
  final _salarioPendiente = TextEditingController(text: '0');
  final _deducciones = TextEditingController(text: '0');
  final _otros = TextEditingController(text: '0');
  final _nota = TextEditingController();

  @override
  void initState() {
    super.initState();
    _empleado = widget.empleados.isEmpty ? null : widget.empleados.first;
    _paramsF.then((p) {
      if (!mounted) return;
      _params = p;
      _utilidadesDias.text =
          (p['dias_utilidades_empresa'] ?? 30).toStringAsFixed(0);
      _cargar();
    });
  }

  @override
  void dispose() {
    _salario.dispose();
    _vacPend.dispose();
    _bonoPend.dispose();
    _utilidadesDias.dispose();
    _salarioPendiente.dispose();
    _deducciones.dispose();
    _otros.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final e = _empleado;
    if (e == null || e.id == null) return;
    setState(() => _cargando = true);
    try {
      final tasa = await Repo.tasa(_fechaEgreso) ?? 0;
      final recibo = await LiquidacionRepo.ultimoRecibo(e.id!);
      final movs = await LiquidacionRepo.movimientos(e.id!);
      final vacs = await LiquidacionRepo.vacaciones(e.id!);
      final saldo = movs
          .where((m) => m.tipo != 'interes')
          .fold<double>(0, (s, m) => s + m.monto);
      final intereses = movs
          .where((m) => m.tipo == 'interes')
          .fold<double>(0, (s, m) => s + m.monto);
      var vac = 0.0;
      var bono = 0.0;
      var vacTom = 0.0;
      var bonoPag = 0.0;
      for (final p in vacs) {
        if (!p.periodoFin.isAfter(_fechaEgreso)) {
          vac += p.pendienteVacaciones;
          bono += p.pendienteBono;
        } else if (!p.periodoInicio.isAfter(_fechaEgreso)) {
          vacTom += p.diasDisfrutados;
          bonoPag += p.diasBonoPagados;
        }
      }
      var salario = (recibo?['salario_mensual'] as num?)?.toDouble() ?? 0;
      if (salario <= 0) salario = e.salarioMensualUsd * tasa;
      var pendiente = 0.0;
      final n = recibo?['nominas'];
      if (n is Map && n['periodo_fin'] != null && tasa > 0) {
        final fin = DateTime.parse(n['periodo_fin']);
        final dias = _fechaEgreso.difference(fin).inDays;
        if (dias > 0) pendiente = salario / 30 * dias;
      }
      if (!mounted) return;
      setState(() {
        _tasa = tasa;
        _saldoGarantia = saldo;
        _intereses = intereses;
        _vacTomadasPeriodo = vacTom;
        _bonoPagadoPeriodo = bonoPag;
        _salario.text = salario == 0 ? '' : salario.toStringAsFixed(2);
        _vacPend.text = vac.toStringAsFixed(2);
        _bonoPend.text = bono.toStringAsFixed(2);
        _salarioPendiente.text =
            pendiente == 0 ? '0' : pendiente.toStringAsFixed(2);
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  ResultadoLiquidacion? _resultado() {
    final p = _params;
    final e = _empleado;
    if (p == null || e == null) return null;
    final salario = _num(_salario);
    if (salario <= 0) return null;
    final engine = LiquidacionEngine(ParametrosLiquidacion.fromMap(p));
    return engine.calcular(LiquidacionEntrada(
      fechaIngreso: e.fechaIngreso,
      fechaEgreso: _fechaEgreso,
      motivo: _motivo,
      salarioNormalMensualBs: salario,
      salarioNormalMensualUsd: _tasa > 0 ? salario / _tasa : 0,
      tasaBcv: _tasa,
      saldoGarantiaBs: _saldoGarantia,
      interesesBs: _intereses,
      diasVacacionesPendientes: _num(_vacPend),
      diasBonoPendientes: _num(_bonoPend),
      diasVacacionesDisfrutadosPeriodo: _vacTomadasPeriodo,
      diasBonoPagadosPeriodo: _bonoPagadoPeriodo,
      diasUtilidadesEmpresa: _num(_utilidadesDias),
      salarioPendienteBs: _num(_salarioPendiente),
      otrosIngresosBs: _num(_otros),
      deduccionesBs: _num(_deducciones),
      aplicaIndemnizacion92: _aplica92,
    ));
  }

  bool _aplica92 = false;

  Future<void> _guardar(bool aprobar) async {
    final r = _resultado();
    final e = _empleado;
    if (r == null || e == null || e.id == null) {
      setState(() => _err = 'Complete el salario normal y seleccione un trabajador');
      return;
    }
    setState(() => _guardando = true);
    try {
      final l = Liquidacion(
        empleadoId: e.id!,
        fechaIngreso: e.fechaIngreso,
        fechaEgreso: _fechaEgreso,
        motivo: _motivo,
        fechaCalculo: DateTime.now(),
        tasaBcv: _tasa,
        salarioNormalUsd: _tasa > 0 ? _num(_salario) / _tasa : 0,
        salarioNormalBs: _num(_salario),
        salarioIntegralBs: r.salarioIntegralDiario,
        anios: r.anios,
        meses: r.meses,
        dias: r.dias,
        garantiaBs: r.garantia,
        interesesBs: r.intereses,
        retroactivoBs: r.retroactivo,
        prestacionesBs: r.prestaciones,
        vacacionesBs: r.vacaciones,
        bonoVacBs: r.bono,
        utilidadesBs: r.utilidades,
        indemnizacionBs: r.indemnizacion,
        salarioPendienteBs: r.salarioPendiente,
        otrosIngresosBs: r.otrosIngresos,
        deduccionesBs: r.deducciones,
        netoBs: r.neto,
        totalUsd: r.totalUsd,
        nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
      );
      final saved = await LiquidacionRepo.guardar(
          l, detallesDesdeResultado(r, null));
      if (aprobar) await LiquidacionRepo.aprobar(saved.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _t(String label, TextEditingController c,
          {TextInputType? keyboard, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          decoration:
              InputDecoration(labelText: label, helperText: hint),
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = _resultado();
    return AlertDialog(
      title: const Text('Nueva liquidación'),
      content: SizedBox(
        width: anchoDialogo(context, 860),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cargando) const LinearProgressIndicator(),
              DropdownButtonFormField<String>(
                value: _empleado?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trabajador'),
                items: [
                  for (final e in widget.empleados)
                    DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.nombreCompleto} · ${e.cedula}')),
                ],
                onChanged: (id) {
                  setState(() {
                    _empleado = widget.empleados.firstWhere((x) => x.id == id);
                  });
                  _cargar();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          'Fecha de egreso: ${_f.format(_fechaEgreso)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _fechaEgreso,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (d != null) {
                          setState(() => _fechaEgreso = d);
                          _cargar();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _motivo,
                      decoration: const InputDecoration(labelText: 'Motivo'),
                      items: [
                        for (final m in MotivosEgreso.todos)
                          DropdownMenuItem(
                              value: m, child: Text(MotivosEgreso.label(m))),
                      ],
                      onChanged: (v) => setState(() {
                        _motivo = v ?? _motivo;
                        _aplica92 =
                            MotivosEgreso.indemnizacionPorDefecto(_motivo);
                      }),
                    ),
                  ),
                ],
              ),
              _t('Salario normal mensual (Bs)', _salario,
                  keyboard: TextInputType.number,
                  hint: 'Tasa BCV: ${_tasa.toStringAsFixed(4)}'),
              Text('Saldo de garantía: Bs ${_fmt(_saldoGarantia)} · '
                  'Intereses: Bs ${_fmt(_intereses)}'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Incluir indemnización Art. 92'),
                value: _aplica92,
                onChanged: (v) => setState(() => _aplica92 = v),
              ),
              const Divider(),
              const Text('Vacaciones y bono',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                      child: _t('Días vacaciones pendientes', _vacPend,
                          keyboard: TextInputType.number,
                          hint: 'Períodos cerrados')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _t('Días bono pendientes', _bonoPend,
                          keyboard: TextInputType.number,
                          hint: 'Períodos cerrados')),
                ],
              ),
              Text('Disfrutados período actual: ${_vacTomadasPeriodo.toStringAsFixed(2)} · '
                  'Bono pagado: ${_bonoPagadoPeriodo.toStringAsFixed(2)}'),
              const Divider(),
              Row(
                children: [
                  Expanded(
                      child: _t('Días utilidades empresa', _utilidadesDias,
                          keyboard: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _t('Salario pendiente (Bs)', _salarioPendiente,
                          keyboard: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                      child: _t('Deducciones / anticipos (Bs)', _deducciones,
                          keyboard: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _t('Otros ingresos (Bs)', _otros,
                          keyboard: TextInputType.number)),
                ],
              ),
              _t('Nota', _nota),
              if (r != null) ...[
                const Divider(),
                Text('Salario integral diario: Bs ${_fmt(r.salarioIntegralDiario)}'),
                Text('Garantía: Bs ${_fmt(r.garantia)} · '
                    'Intereses: Bs ${_fmt(r.intereses)}'),
                Text('Retroactivo: Bs ${_fmt(r.retroactivo)} · '
                    'Se paga: Bs ${_fmt(r.prestaciones)}'),
                const SizedBox(height: 6),
                for (final l in r.lineas)
                  Text('${l.nombre}: Bs ${_fmt(l.monto)}',
                      style: const TextStyle(fontSize: 12)),
                const Divider(),
                Text('Neto: Bs ${_fmt(r.neto)} · USD ${_fmt(r.totalUsd)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final a in r.advertencias)
                  Text(a,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error)),
              ],
              if (_err != null)
                Text(_err!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        OutlinedButton(
            onPressed: _guardando ? null : () => _guardar(false),
            child: const Text('Guardar borrador')),
        FilledButton(
            onPressed: _guardando ? null : () => _guardar(true),
            child: const Text('Guardar y aprobar')),
      ],
    );
  }
}
