import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';

final money = NumberFormat('#,##0.00', 'es');
final usd = NumberFormat('#,##0.00', 'en');

String _extraEmpleado(Empleado e) {
  final partes = <String>[
    if (e.telefono != null && e.telefono!.isNotEmpty) 'Tel: ${e.telefono}',
    if (e.fechaNacimiento != null)
      'Nac: ${DateFormat('dd/MM/yyyy').format(e.fechaNacimiento!)}',
  ];
  return partes.isEmpty ? '' : '\n${partes.join(' · ')}';
}

class EmpleadosPage extends StatefulWidget {
  final bool puedeEditar;
  const EmpleadosPage({super.key, required this.puedeEditar});
  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  late Future<List<Empleado>> _f = Repo.empleados();
  bool? _estado;
  String? _modalidad;
  void _reload() => setState(() => _f = Repo.empleados());

  Future<void> _editar(Empleado? e) async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _EmpleadoDialog(e ?? Empleado()));
    if (ok == true) _reload();
  }

  Widget _filtro(List<Empleado> l) {
    final activos = l.where((e) => e.activo).length;
    final inactivos = l.length - activos;
    final normales = l.where((e) => e.modalidad == 'normal').length;
    final contratados = l.length - normales;
    Widget chipEstado(String texto, bool? valor) => ChoiceChip(
          label: Text(texto),
          selected: _estado == valor,
          onSelected: (_) => setState(() => _estado = valor),
        );
    Widget chipModalidad(String texto, String? valor) => ChoiceChip(
          label: Text(texto),
          selected: _modalidad == valor,
          onSelected: (_) => setState(() => _modalidad = valor),
        );
    if (esMovil(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _estado == null
                    ? 'todos'
                    : (_estado! ? 'activos' : 'inactivos'),
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Mostrar',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'todos', child: Text('Todos (${l.length})')),
                  DropdownMenuItem(
                      value: 'activos', child: Text('Activos ($activos)')),
                  DropdownMenuItem(
                      value: 'inactivos',
                      child: Text('No activos ($inactivos)')),
                ],
                onChanged: (v) => setState(() {
                  _estado =
                      v == 'activos' ? true : (v == 'inactivos' ? false : null);
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _modalidad ?? 'todas',
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Nómina',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'todas', child: Text('Todas (${l.length})')),
                  DropdownMenuItem(
                      value: 'normal', child: Text('Normal ($normales)')),
                  DropdownMenuItem(
                      value: 'contratado',
                      child: Text('Contratados ($contratados)')),
                ],
                onChanged: (v) => setState(
                    () => _modalidad = v == 'todas' ? null : v),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Mostrar:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              chipEstado('Todos (${l.length})', null),
              chipEstado('Activos ($activos)', true),
              chipEstado('No activos ($inactivos)', false),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Nómina:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              chipModalidad('Todas (${l.length})', null),
              chipModalidad('Normal ($normales)', 'normal'),
              chipModalidad('Contratados ($contratados)', 'contratado'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: widget.puedeEditar
            ? FloatingActionButton.extended(
                onPressed: () => _editar(null),
                icon: const Icon(Icons.add),
                label: const Text('Empleado'))
            : null,
        body: FutureBuilder<List<Empleado>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final l = s.data!;
            final filtrados = l
                .where((e) => _estado == null || e.activo == _estado)
                .where((e) => _modalidad == null || e.modalidad == _modalidad)
                .toList();
            return Column(
              children: [
                _filtro(l),
                Expanded(
                  child: l.isEmpty
                      ? const Center(child: Text('Sin empleados'))
                      : filtrados.isEmpty
                          ? const Center(
                              child: Text('Sin empleados en este filtro'))
                          : esMovil(context)
                              ? ListView(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 88),
                                  children: [
                                    for (final e in filtrados)
                                      Card(
                                        child: ListTile(
                                          title: Text(e.nombreCompleto),
                                          subtitle: Text(
                                              '${e.cedula} · ${e.cargo ?? ''}\n'
                                              '${e.departamento ?? 'Sin departamento'} · ${e.tipo} · ${e.frecuenciaPago}'
                                              '${e.modalidad == 'contratado' ? ' · Contratado' : ''}'
                                              '${_extraEmpleado(e)}'),
                                          isThreeLine: true,
                                          trailing: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  'US\$ ${usd.format(e.salarioMensualUsd)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Icon(
                                                  e.activo
                                                      ? Icons.check_circle
                                                      : Icons.cancel,
                                                  size: 18,
                                                  color: e.activo
                                                      ? Paleta.ingreso
                                                      : Paleta.egreso),
                                            ],
                                          ),
                                          onTap: widget.puedeEditar
                                              ? () => _editar(e)
                                              : null,
                                        ),
                                      ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Cédula')),
                                        DataColumn(label: Text('Nombre')),
                                        DataColumn(label: Text('Nacimiento')),
                                        DataColumn(label: Text('Teléfono')),
                                        DataColumn(label: Text('Tipo')),
                                        DataColumn(label: Text('Cargo')),
                                        DataColumn(
                                            label: Text('Departamento')),
                                        DataColumn(label: Text('Frecuencia')),
                                        DataColumn(label: Text('Nómina')),
                                        DataColumn(
                                            label: Text('Salario mensual (USD)'),
                                            numeric: true),
                                        DataColumn(label: Text('Activo')),
                                      ],
                                      rows: [
                                        for (final e in filtrados)
                                          DataRow(
                                            onSelectChanged: widget.puedeEditar
                                                ? (_) => _editar(e)
                                                : null,
                                            cells: [
                                              DataCell(Text(e.cedula)),
                                              DataCell(Text(e.nombreCompleto)),
                                              DataCell(Text(e.fechaNacimiento ==
                                                      null
                                                  ? ''
                                                  : DateFormat('dd/MM/yyyy')
                                                      .format(
                                                          e.fechaNacimiento!))),
                                              DataCell(Text(e.telefono ?? '')),
                                              DataCell(Text(e.tipo)),
                                              DataCell(Text(e.cargo ?? '')),
                                              DataCell(
                                                  Text(e.departamento ?? '')),
                                              DataCell(Text(e.frecuenciaPago)),
                                              DataCell(
                                                  Text(e.modalidad == 'contratado'
                                                      ? 'Contratado'
                                                      : 'Normal')),
                                              DataCell(Text(
                                                  'US\$ ${usd.format(e.salarioMensualUsd)}')),
                                              DataCell(Icon(e.activo
                                                  ? Icons.check
                                                  : Icons.close)),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                ),
              ],
            );
          },
        ),
      );
}

class _EmpleadoDialog extends StatefulWidget {
  final Empleado e;
  const _EmpleadoDialog(this.e);
  @override
  State<_EmpleadoDialog> createState() => _EmpleadoDialogState();
}

class _EmpleadoDialogState extends State<_EmpleadoDialog> {
  final _k = GlobalKey<FormState>();
  late final e = widget.e;
  final _depts = Repo.departamentos();
  String? _err;

  Widget _t(String l, String? v, void Function(String) set,
          {bool req = false, TextInputType? kt}) =>
      TextFormField(
        initialValue: v,
        keyboardType: kt,
        decoration: InputDecoration(labelText: l),
        validator: req ? (x) => (x == null || x.trim().isEmpty) ? 'Requerido' : null : null,
        onChanged: set,
      );

  Widget _dd(String l, String v, List<String> o, void Function(String) set) =>
      DropdownButtonFormField<String>(
        value: v,
        decoration: InputDecoration(labelText: l),
        items: [for (final x in o) DropdownMenuItem(value: x, child: Text(x))],
        onChanged: (x) => set(x!),
      );

  Future<void> _fecha() async {
    final d = await showDatePicker(
        context: context,
        initialDate: e.fechaIngreso,
        firstDate: DateTime(1970),
        lastDate: DateTime(2100));
    if (d != null) setState(() => e.fechaIngreso = d);
  }

  Future<void> _fechaNacimiento() async {
    final d = await showDatePicker(
        context: context,
        initialDate: e.fechaNacimiento ?? DateTime(1990, 1, 1),
        firstDate: DateTime(1900),
        lastDate: DateTime.now());
    if (d != null) setState(() => e.fechaNacimiento = d);
  }

  Future<void> _guardar() async {
    if (!_k.currentState!.validate()) return;
    try {
      await Repo.guardarEmpleado(e);
      if (mounted) Navigator.pop(context, true);
    } catch (x) {
      setState(() => _err = '$x');
    }
  }

  Widget _departamento() => FutureBuilder<List<Departamento>>(
        future: _depts,
        builder: (_, s) {
          if (s.hasError) {
            return Text('No se pudieron cargar los departamentos: ${s.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error));
          }
          if (!s.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            );
          }
          final deps = s.data!
              .where((d) => d.activo || d.id == e.departamentoId)
              .toList();
          if (e.departamentoId != null &&
              !deps.any((d) => d.id == e.departamentoId)) {
            deps.add(Departamento(
                id: e.departamentoId,
                nombre: e.departamento ?? 'Sin nombre'));
          }
          return DropdownButtonFormField<String>(
            initialValue: e.departamentoId ?? '',
            decoration: const InputDecoration(labelText: 'Departamento'),
            items: [
              const DropdownMenuItem(
                  value: '', child: Text('Sin departamento')),
              for (final d in deps)
                DropdownMenuItem(
                  value: d.id!,
                  child: Text(d.activo ? d.nombre : '${d.nombre} (inactivo)'),
                ),
            ],
            onChanged: (v) => setState(() {
              if (v == null || v.isEmpty) {
                e.departamentoId = null;
                e.departamento = null;
              } else {
                e.departamentoId = v;
                e.departamento = deps.firstWhere((d) => d.id == v).nombre;
              }
            }),
          );
        },
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(e.id == null ? 'Nuevo empleado' : 'Editar empleado'),
        content: SizedBox(
          width: anchoDialogo(context, 460),
          child: Form(
            key: _k,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _t('Cédula', e.cedula, (v) => e.cedula = v.trim(), req: true),
                _t('Nombres', e.nombres, (v) => e.nombres = v, req: true),
                _t('Apellidos', e.apellidos, (v) => e.apellidos = v, req: true),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Nacimiento: ${e.fechaNacimiento == null ? '—' : DateFormat('dd/MM/yyyy').format(e.fechaNacimiento!)}'),
                  trailing: const Icon(Icons.cake_outlined),
                  onTap: _fechaNacimiento,
                ),
                _t('Teléfono', e.telefono, (v) => e.telefono = v.trim(),
                    kt: TextInputType.phone),
                _t('Cargo', e.cargo, (v) => e.cargo = v),
                _departamento(),
                _dd('Tipo (Art. 41/43 LOT)', e.tipo, ['empleado', 'obrero'],
                    (v) => setState(() => e.tipo = v)),
                DropdownButtonFormField<String>(
                  initialValue: e.modalidad,
                  decoration:
                      const InputDecoration(labelText: 'Modalidad de nómina'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(
                        value: 'contratado', child: Text('Contratado')),
                  ],
                  onChanged: (v) =>
                      setState(() => e.modalidad = v ?? 'normal'),
                ),
                if (e.modalidad == 'contratado')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        'Contratado: solo sueldo, sin deducciones. '
                        'Puede pagarse semanal, quincenal o mensual.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                _dd('Jornada', e.jornada, ['diurna', 'nocturna', 'mixta'],
                    (v) => setState(() => e.jornada = v)),
                _dd('Frecuencia de pago', e.frecuenciaPago,
                    ['semanal', 'quincenal', 'mensual'],
                    (v) => setState(() => e.frecuenciaPago = v)),
                _t('Salario mensual (USD)', e.salarioMensualUsd == 0 ? '' : '${e.salarioMensualUsd}',
                    (v) => e.salarioMensualUsd = double.tryParse(v.replaceAll(',', '.')) ?? 0,
                    req: true, kt: TextInputType.number),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ingreso: ${DateFormat('dd/MM/yyyy').format(e.fechaIngreso)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _fecha,
                ),
                _t('Banco', e.banco, (v) => e.banco = v),
                _t('Cuenta', e.cuenta, (v) => e.cuenta = v),
                _t('Correo', e.email, (v) => e.email = v),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: e.activo,
                    onChanged: (v) => setState(() => e.activo = v)),
                if (_err != null)
                  Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}
