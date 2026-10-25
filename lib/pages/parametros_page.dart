import 'package:flutter/material.dart';
import '../services/repo.dart';

class ParametrosPage extends StatefulWidget {
  final bool puedeEditar;
  const ParametrosPage({super.key, required this.puedeEditar});
  @override
  State<ParametrosPage> createState() => _ParametrosPageState();
}

class _ParametrosPageState extends State<ParametrosPage> {
  late Future<List<Object>> _f = _load();

  Future<List<Object>> _load() async =>
      [await Repo.ajustes(), await Repo.parametros()];

  Future<void> _editarTexto(Map<String, dynamic> a) async {
    final ctl = TextEditingController(text: '${a['valor'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a['clave']),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(a['descripcion'] ?? ''),
          TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Valor')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) {
      await Repo.guardarAjuste(a['clave'], ctl.text.trim());
      setState(() => _f = _load());
    }
  }

  Future<void> _editar(Map<String, dynamic> p) async {
    final ctl = TextEditingController(text: '${p['valor']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p['clave']),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p['descripcion'] ?? ''),
          Text(p['referencia_legal'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
          TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Valor')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctl.text.replaceAll(',', '.'));
      if (v != null) {
        await Repo.guardarParametro(p['clave'], v);
        setState(() => _f = _load());
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final aj = s.data![0] as List<Map<String, dynamic>>;
          final ps = s.data![1] as List<Map<String, dynamic>>;
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Empresa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Datos que aparecen en recibos y PDF.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            for (final a in aj)
              ListTile(
                leading: const Icon(Icons.business),
                title: Text('${a['clave']} = ${(a['valor'] ?? '').toString().isEmpty ? '—' : a['valor']}'),
                subtitle: Text(a['descripcion'] ?? ''),
                onTap: widget.puedeEditar ? () => _editarTexto(a) : null,
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'Aviso: la LOT adjunta (1997) fue reemplazada por la LOTTT (2012). '
                  'Los porcentajes de IVSS, RPE y FAOV no provienen de los documentos adjuntos. '
                  'El IVSS se calcula por lunes del período con un tope mensual de '
                  '5 salarios mínimos (0 = sin tope). '
                  'Valide cada parámetro con la normativa vigente antes de pagar.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            for (final p in ps)
              ListTile(
                title: Text('${p['clave']} = ${p['valor']}'),
                subtitle: Text('${p['descripcion'] ?? ''}  [${p['referencia_legal'] ?? ''}]'),
                onTap: widget.puedeEditar ? () => _editar(p) : null,
              ),
          ]);
        },
      );
}
