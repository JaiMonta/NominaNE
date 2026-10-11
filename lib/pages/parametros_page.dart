import 'package:flutter/material.dart';
import '../services/repo.dart';

class ParametrosPage extends StatefulWidget {
  final bool puedeEditar;
  const ParametrosPage({super.key, required this.puedeEditar});
  @override
  State<ParametrosPage> createState() => _ParametrosPageState();
}

class _ParametrosPageState extends State<ParametrosPage> {
  late Future<List<Map<String, dynamic>>> _f = Repo.parametros();

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
        setState(() => _f = Repo.parametros());
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Aviso: la LOT adjunta (1997) fue reemplazada por la LOTTT (2012). '
                  'Los porcentajes de IVSS, RPE y FAOV no provienen de los documentos adjuntos. '
                  'Valide cada parámetro con la normativa vigente antes de pagar.',
                  style: TextStyle(color: Colors.deepOrange)),
            ),
            for (final p in s.data!)
              ListTile(
                title: Text('${p['clave']} = ${p['valor']}'),
                subtitle: Text('${p['descripcion'] ?? ''}  [${p['referencia_legal'] ?? ''}]'),
                onTap: widget.puedeEditar ? () => _editar(p) : null,
              ),
          ]);
        },
      );
}
