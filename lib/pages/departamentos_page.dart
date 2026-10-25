import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../models/models.dart';
import '../services/repo.dart';

class DepartamentosPage extends StatefulWidget {
  final bool puedeEditar;
  const DepartamentosPage({super.key, required this.puedeEditar});
  @override
  State<DepartamentosPage> createState() => _DepartamentosPageState();
}

class _DepartamentosPageState extends State<DepartamentosPage> {
  late Future<List<Departamento>> _f = Repo.departamentos();
  void _reload() => setState(() => _f = Repo.departamentos());

  Future<void> _editar(Departamento? d) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _DepartamentoDialog(d ?? Departamento()));
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: widget.puedeEditar
            ? FloatingActionButton.extended(
                onPressed: () => _editar(null),
                icon: const Icon(Icons.add),
                label: const Text('Departamento'))
            : null,
        body: FutureBuilder<List<Departamento>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final l = s.data!;
            if (l.isEmpty) {
              return const Center(child: Text('Sin departamentos'));
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final d in l)
                  ListTile(
                    leading: Icon(
                        d.activo ? Icons.business : Icons.business_outlined),
                    title: Text(d.nombre),
                    subtitle: Text('Orden: ${d.orden}'),
                    trailing:
                        d.activo ? null : const Chip(label: Text('inactivo')),
                    onTap: widget.puedeEditar ? () => _editar(d) : null,
                  ),
              ],
            );
          },
        ),
      );
}

class _DepartamentoDialog extends StatefulWidget {
  final Departamento d;
  const _DepartamentoDialog(this.d);
  @override
  State<_DepartamentoDialog> createState() => _DepartamentoDialogState();
}

class _DepartamentoDialogState extends State<_DepartamentoDialog> {
  late final d = widget.d;
  String? _err;

  Future<void> _guardar() async {
    if (d.nombre.trim().isEmpty) {
      setState(() => _err = 'El nombre es requerido');
      return;
    }
    try {
      d.nombre = d.nombre.trim();
      await Repo.guardarDepartamento(d);
      if (mounted) Navigator.pop(context, true);
    } catch (x) {
      setState(() => _err = '$x');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(d.id == null ? 'Nuevo departamento' : 'Editar departamento'),
        content: SizedBox(
          width: anchoDialogo(context, 400),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                initialValue: d.nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                onChanged: (v) => d.nombre = v),
            TextFormField(
                initialValue: '${d.orden}',
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Orden (menor primero)'),
                onChanged: (v) => d.orden = int.tryParse(v) ?? 999),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: d.activo,
                onChanged: (v) => setState(() => d.activo = v)),
            if (_err != null)
              Text(_err!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}
