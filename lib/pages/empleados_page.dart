import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/repo.dart';

final money = NumberFormat('#,##0.00', 'es');
final usd = NumberFormat('#,##0.00', 'en');

class EmpleadosPage extends StatefulWidget {
  final bool puedeEditar;
  const EmpleadosPage({super.key, required this.puedeEditar});
  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  late Future<List<Empleado>> _f = Repo.empleados();
  void _reload() => setState(() => _f = Repo.empleados());

  Future<void> _editar(Empleado? e) async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _EmpleadoDialog(e ?? Empleado()));
    if (ok == true) _reload();
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
            if (l.isEmpty) return const Center(child: Text('Sin empleados'));
            return SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Cédula')),
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Tipo')),
                    DataColumn(label: Text('Cargo')),
                    DataColumn(label: Text('Frecuencia')),
                    DataColumn(label: Text('Salario mensual (USD)'), numeric: true),
                    DataColumn(label: Text('Activo')),
                  ],
                  rows: [
                    for (final e in l)
                      DataRow(
                        onSelectChanged:
                            widget.puedeEditar ? (_) => _editar(e) : null,
                        cells: [
                          DataCell(Text(e.cedula)),
                          DataCell(Text(e.nombreCompleto)),
                          DataCell(Text(e.tipo)),
                          DataCell(Text(e.cargo ?? '')),
                          DataCell(Text(e.frecuenciaPago)),
                          DataCell(Text('US\$ ${usd.format(e.salarioMensualUsd)}')),
                          DataCell(Icon(e.activo ? Icons.check : Icons.close)),
                        ],
                      )
                  ],
                ),
              ),
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

  Future<void> _guardar() async {
    if (!_k.currentState!.validate()) return;
    try {
      await Repo.guardarEmpleado(e);
      if (mounted) Navigator.pop(context, true);
    } catch (x) {
      setState(() => _err = '$x');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(e.id == null ? 'Nuevo empleado' : 'Editar empleado'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: _k,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _t('Cédula', e.cedula, (v) => e.cedula = v.trim(), req: true),
                _t('Nombres', e.nombres, (v) => e.nombres = v, req: true),
                _t('Apellidos', e.apellidos, (v) => e.apellidos = v, req: true),
                _t('Cargo', e.cargo, (v) => e.cargo = v),
                _t('Departamento', e.departamento, (v) => e.departamento = v),
                _dd('Tipo (Art. 41/43 LOT)', e.tipo, ['empleado', 'obrero'],
                    (v) => setState(() => e.tipo = v)),
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
                  Text(_err!, style: const TextStyle(color: Colors.red)),
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
