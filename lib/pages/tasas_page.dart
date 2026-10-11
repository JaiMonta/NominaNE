import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../services/repo.dart';

class TasasPage extends StatefulWidget {
  final bool puedeEditar;
  const TasasPage({super.key, required this.puedeEditar});
  @override
  State<TasasPage> createState() => _TasasPageState();
}

class _TasasPageState extends State<TasasPage> {
  late Future<List<Map<String, dynamic>>> _f = Repo.tasas();
  void _reload() => setState(() => _f = Repo.tasas());

  Future<void> _nueva() async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _TasaDialog());
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: widget.puedeEditar
            ? FloatingActionButton.extended(
                onPressed: _nueva,
                icon: const Icon(Icons.add),
                label: const Text('Tasa BCV'))
            : null,
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    'Tasa oficial del BCV (Bs por USD) usada para convertir la '
                    'nómina a Bolívares (VES). Cargue la tasa del día; para una '
                    'nómina se usa la tasa más reciente con fecha <= al cierre del período.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              if (s.data!.isEmpty)
                const Center(child: Padding(
                    padding: EdgeInsets.all(24), child: Text('Sin tasas registradas'))),
              for (final t in s.data!)
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text('${t['fecha']} · ${t['moneda']} = ${t['tasa']} Bs'),
                  subtitle: Text('Fuente: ${t['fuente'] ?? '—'}'),
                ),
            ]);
          },
        ),
      );
}

class _TasaDialog extends StatefulWidget {
  const _TasaDialog();
  @override
  State<_TasaDialog> createState() => _TasaDialogState();
}

class _TasaDialogState extends State<_TasaDialog> {
  DateTime fechaDia = DateTime.now();
  double tasa = 0;
  String fuente = 'BCV';
  String? _err;
  bool _busy = false;

  Future<void> _pick() async {
    final d = await showDatePicker(
        context: context,
        initialDate: fechaDia,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (d != null) setState(() => fechaDia = d);
  }

  Future<void> _guardar() async {
    if (tasa <= 0) {
      setState(() => _err = 'Indique una tasa mayor a 0');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Repo.guardarTasa(fechaDia, tasa, fuente: fuente.trim().isEmpty ? 'BCV' : fuente.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (x) {
      setState(() {
        _err = '$x';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Tasa BCV (Bs por USD)'),
        content: SizedBox(
          width: anchoDialogo(context, 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Fecha: ${fecha(fechaDia)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pick,
            ),
            TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tasa (ej. 36,50)'),
                onChanged: (v) => tasa = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            TextField(
                decoration: const InputDecoration(labelText: 'Fuente'),
                onChanged: (v) => fuente = v),
            if (_err != null)
              Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _busy ? null : _guardar, child: const Text('Guardar')),
        ],
      );
}
