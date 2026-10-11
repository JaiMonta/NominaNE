import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';

class ConceptosPage extends StatefulWidget {
  final bool puedeEditar;
  const ConceptosPage({super.key, required this.puedeEditar});
  @override
  State<ConceptosPage> createState() => _ConceptosPageState();
}

class _ConceptosPageState extends State<ConceptosPage> {
  late Future<List<Concepto>> _f = Repo.conceptos();
  void _reload() => setState(() => _f = Repo.conceptos());

  Future<void> _editar(Concepto? c) async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _ConceptoDialog(c ?? Concepto()));
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: widget.puedeEditar
            ? FloatingActionButton.extended(
                onPressed: () => _editar(null),
                icon: const Icon(Icons.add),
                label: const Text('Concepto'))
            : null,
        body: FutureBuilder<List<Concepto>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
              for (final c in s.data!)
                ListTile(
                  leading: Icon(
                      c.tipo == 'ingreso' ? Icons.add_circle : Icons.remove_circle,
                      color: c.tipo == 'ingreso' ? Paleta.ingreso : Paleta.egreso),
                  title: Text('${c.codigo} · ${c.nombre}'),
                  subtitle: Text([
                    c.tipo,
                    c.esSalarial ? 'salarial' : 'no salarial',
                    c.calculo,
                    if (c.baseLegal != null) c.baseLegal!,
                  ].join(' · ')),
                  trailing: c.activo ? null : const Chip(label: Text('inactivo')),
                  onTap: widget.puedeEditar ? () => _editar(c) : null,
                ),
            ]);
          },
        ),
      );
}

class _ConceptoDialog extends StatefulWidget {
  final Concepto c;
  const _ConceptoDialog(this.c);
  @override
  State<_ConceptoDialog> createState() => _ConceptoDialogState();
}

class _ConceptoDialogState extends State<_ConceptoDialog> {
  late final c = widget.c;
  String? _err;

  Future<void> _guardar() async {
    if (c.codigo.trim().isEmpty || c.nombre.trim().isEmpty) {
      setState(() => _err = 'Código y nombre son requeridos');
      return;
    }
    try {
      c.codigo = c.codigo.trim().toUpperCase();
      await Repo.guardarConcepto(c);
      if (mounted) Navigator.pop(context, true);
    } catch (x) {
      setState(() => _err = '$x');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(c.id == null ? 'Nuevo concepto' : 'Editar concepto'),
        content: SizedBox(
          width: anchoDialogo(context, 420),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  initialValue: c.codigo,
                  enabled: c.id == null,
                  decoration: const InputDecoration(labelText: 'Código'),
                  onChanged: (v) => c.codigo = v),
              TextFormField(
                  initialValue: c.nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => c.nombre = v),
              DropdownButtonFormField<String>(
                value: c.tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                  DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                ],
                onChanged: (v) => setState(() => c.tipo = v!),
              ),
              DropdownButtonFormField<String>(
                value: c.calculo,
                decoration: const InputDecoration(labelText: 'Cálculo'),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual (monto en novedad)')),
                  DropdownMenuItem(value: 'fijo', child: Text('Fijo (valor × cantidad)')),
                  DropdownMenuItem(
                      value: 'porcentaje_salario', child: Text('% del salario')),
                ],
                onChanged: (v) => setState(() => c.calculo = v!),
              ),
              TextFormField(
                  initialValue: c.valor == 0 ? '' : '${c.valor}',
                  decoration: const InputDecoration(
                      labelText: 'Valor (monto fijo o fracción, ej. 0.10 = 10%)'),
                  onChanged: (v) => c.valor = double.tryParse(v.replaceAll(',', '.')) ?? 0),
              TextFormField(
                  initialValue: c.baseLegal,
                  decoration: const InputDecoration(labelText: 'Base legal'),
                  onChanged: (v) => c.baseLegal = v),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Es salarial (Art. 133 LOT)'),
                  value: c.esSalarial,
                  onChanged: (v) => setState(() => c.esSalarial = v)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: c.activo,
                  onChanged: (v) => setState(() => c.activo = v)),
              if (_err != null)
                Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}
