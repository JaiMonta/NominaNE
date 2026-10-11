import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/repo.dart';

class NovedadesPage extends StatefulWidget {
  final bool puedeEditar;
  const NovedadesPage({super.key, required this.puedeEditar});
  @override
  State<NovedadesPage> createState() => _NovedadesPageState();
}

class _NovedadesPageState extends State<NovedadesPage> {
  late Future<List<Map<String, dynamic>>> _f = Repo.novedades();
  void _reload() => setState(() => _f = Repo.novedades());

  Future<void> _nueva() async {
    final emps = await Repo.empleados();
    // Se excluyen los conceptos que el motor calcula solo (sueldo, deducciones de ley, utilidades).
    const calculados = {'SUELDO', 'IVSS', 'RPE', 'FAOV', 'UTILIDADES'};
    final cons = (await Repo.conceptos())
        .where((c) => c.activo && !calculados.contains(c.codigo))
        .toList();
    if (!mounted) return;
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _NovedadDialog(emps, cons));
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: widget.puedeEditar
            ? FloatingActionButton.extended(
                onPressed: _nueva,
                icon: const Icon(Icons.add),
                label: const Text('Novedad'))
            : null,
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) {
              return const Center(
                  child: Text('Sin novedades (horas extra, bonos, préstamos, vacaciones...)'));
            }
            return ListView(children: [
              for (final n in s.data!)
                ListTile(
                  title: Text(
                      '${n['empleados']?['nombres']} ${n['empleados']?['apellidos']} — '
                      '${n['conceptos']?['nombre']}'),
                  subtitle: Text('Cant: ${n['cantidad']} · Monto US\$: ${n['monto_usd']} · '
                      '${n['periodo_inicio'] ?? 'recurrente'}'
                      '${n['periodo_fin'] != null ? ' a ${n['periodo_fin']}' : ''}'
                      '${n['nota'] != null ? ' · ${n['nota']}' : ''}'),
                  trailing: widget.puedeEditar
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await Repo.borrarNovedad(n['id']);
                            _reload();
                          })
                      : null,
                ),
            ]);
          },
        ),
      );
}

class _NovedadDialog extends StatefulWidget {
  final List<Empleado> emps;
  final List<Concepto> cons;
  const _NovedadDialog(this.emps, this.cons);
  @override
  State<_NovedadDialog> createState() => _NovedadDialogState();
}

class _NovedadDialogState extends State<_NovedadDialog> {
  String? emp, con, nota;
  double cantidad = 1, monto = 0;
  DateTime? ini, fin;
  bool recurrente = false;
  String? _err;

  Future<DateTime?> _pick() => showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100));

  Future<void> _guardar() async {
    if (emp == null || con == null || (!recurrente && (ini == null || fin == null))) {
      setState(() => _err = 'Complete empleado, concepto y período');
      return;
    }
    try {
      await Repo.agregarNovedad({
        'empleado_id': emp,
        'concepto_id': con,
        'cantidad': cantidad,
        'monto_usd': monto,
        'nota': nota,
        'periodo_inicio': recurrente ? null : fecha(ini!),
        'periodo_fin': recurrente ? null : fecha(fin!),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (x) {
      setState(() => _err = '$x');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nueva novedad'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Empleado'),
                items: [
                  for (final e in widget.emps)
                    DropdownMenuItem(value: e.id, child: Text(e.nombreCompleto))
                ],
                onChanged: (v) => emp = v,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Concepto'),
                items: [
                  for (final c in widget.cons)
                    DropdownMenuItem(value: c.id, child: Text('${c.codigo} · ${c.nombre}'))
                ],
                onChanged: (v) => con = v,
              ),
              TextFormField(
                  initialValue: '1',
                  decoration: const InputDecoration(labelText: 'Cantidad (horas, días, unidades)'),
                  onChanged: (v) => cantidad = double.tryParse(v.replaceAll(',', '.')) ?? 0),
              TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'Monto USD (0 = que lo calcule el sistema)'),
                  onChanged: (v) => monto = double.tryParse(v.replaceAll(',', '.')) ?? 0),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recurrente (todas las nóminas)'),
                  value: recurrente,
                  onChanged: (v) => setState(() => recurrente = v)),
              if (!recurrente) ...[
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
                      if (d != null) setState(() => fin = d);
                    }),
              ],
              TextFormField(
                  decoration: const InputDecoration(labelText: 'Nota'),
                  onChanged: (v) => nota = v),
              if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}
