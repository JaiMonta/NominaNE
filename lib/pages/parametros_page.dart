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

  TimeOfDay? _hora(String? valor) {
    final m =
        RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch((valor ?? '').trim());
    if (m == null) return null;
    return TimeOfDay(
      hour: int.parse(m.group(1)!),
      minute: int.parse(m.group(2)!),
    );
  }

  String _tituloHorario(String clave) {
    switch (clave) {
      case 'asistencia_diurna_entrada':
        return 'Entrada diurna';
      case 'asistencia_diurna_salida':
        return 'Salida diurna';
      case 'asistencia_nocturna_entrada':
        return 'Entrada nocturna';
      case 'asistencia_nocturna_salida':
        return 'Salida nocturna';
      case 'asistencia_mixta_entrada':
        return 'Entrada mixta';
      case 'asistencia_mixta_salida':
        return 'Salida mixta';
      case 'asistencia_tolerancia_min':
        return 'Tolerancia';
      default:
        return clave;
    }
  }

  bool _esTolerancia(Map<String, dynamic> a) =>
      (a['clave'] ?? '').toString() == 'asistencia_tolerancia_min';

  Future<void> _editarHora(Map<String, dynamic> a) async {
    final t = await showTimePicker(
      context: context,
      initialTime: _hora('${a['valor']}') ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (t == null || !mounted) return;
    final valor = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    await Repo.guardarAjuste(a['clave'], valor);
    if (mounted) setState(() => _f = _load());
  }

  Future<void> _editarTolerancia(Map<String, dynamic> a) async {
    final ctl = TextEditingController(text: '${a['valor'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a['clave']),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(a['descripcion'] ?? ''),
          TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) {
      ctl.dispose();
      return;
    }
    final v = int.tryParse(ctl.text.trim());
    ctl.dispose();
    if (v == null || v < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingrese un número de minutos válido')),
        );
      }
      return;
    }
    await Repo.guardarAjuste(a['clave'], '$v');
    if (mounted) setState(() => _f = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final aj = s.data![0] as List<Map<String, dynamic>>;
          final ps = s.data![1] as List<Map<String, dynamic>>;
          final ajustesEmpresa = aj
              .where((a) =>
                  !(a['clave'] as String? ?? '').startsWith('asistencia_'))
              .toList();
          final horarios = aj
              .where((a) =>
                  (a['clave'] as String? ?? '').startsWith('asistencia_'))
              .toList();
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
            for (final a in ajustesEmpresa)
              ListTile(
                leading: const Icon(Icons.business),
                title: Text('${a['clave']} = ${(a['valor'] ?? '').toString().isEmpty ? '—' : a['valor']}'),
                subtitle: Text(a['descripcion'] ?? ''),
                onTap: widget.puedeEditar ? () => _editarTexto(a) : null,
              ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Asistencia',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                  'Horarios para calcular retardos. La jornada se toma de la ficha del empleado.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            for (final a in horarios)
              ListTile(
                leading: Icon(_esTolerancia(a)
                    ? Icons.timer_outlined
                    : Icons.schedule),
                title: Text(
                    '${_tituloHorario((a['clave'] ?? '').toString())} = ${a['valor'] ?? '—'}'),
                subtitle: Text(a['descripcion'] ?? ''),
                onTap: widget.puedeEditar
                    ? () => _esTolerancia(a)
                        ? _editarTolerancia(a)
                        : _editarHora(a)
                    : null,
              ),
            const Divider(),
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
