import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/models.dart';
import '../services/bcv_service.dart';
import '../services/repo.dart';

class RecalcularNominaDialog extends StatefulWidget {
  final Nomina nomina;

  const RecalcularNominaDialog({super.key, required this.nomina});

  @override
  State<RecalcularNominaDialog> createState() => _RecalcularNominaDialogState();
}

class _RecalcularNominaDialogState extends State<RecalcularNominaDialog> {
  String _modo = 'hoy';
  bool _cargandoHoy = true;
  BcvTasa? _bcvHoy;
  String? _errorHoy;
  bool _cargandoTasas = true;
  List<Map<String, dynamic>> _tasas = [];
  String? _errorTasas;
  int _tasaIndex = 0;
  final _manual = TextEditingController();
  DateTime _fechaManual = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarHoy();
    _cargarTasas();
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _cargarHoy() async {
    setState(() {
      _cargandoHoy = true;
      _errorHoy = null;
    });
    try {
      final r = await BcvService.delDia(DateTime.now());
      if (!mounted) return;
      setState(() {
        _bcvHoy = r;
        _cargandoHoy = false;
        if (r == null) _errorHoy = 'No se pudo obtener la tasa BCV.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoHoy = false;
        _errorHoy = 'No se pudo consultar el BCV.';
      });
    }
  }

  Future<void> _cargarTasas() async {
    try {
      final l = await Repo.tasas();
      if (!mounted) return;
      setState(() {
        _tasas = l;
        _cargandoTasas = false;
        _errorTasas = l.isEmpty ? 'No hay tasas registradas.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoTasas = false;
        _errorTasas = 'No se pudieron cargar las tasas.';
      });
    }
  }

  Map<String, dynamic>? get _tasaRegistrada =>
      _tasas.isEmpty || _tasaIndex >= _tasas.length
          ? null
          : _tasas[_tasaIndex];

  double? get _tasa {
    switch (_modo) {
      case 'hoy':
        return _bcvHoy?.tasa;
      case 'registrada':
        final t = _tasaRegistrada;
        return t == null ? null : double.tryParse('${t['tasa']}');
      case 'manual':
        return double.tryParse(_manual.text.trim().replaceAll(',', '.'));
      default:
        return null;
    }
  }

  DateTime? get _fechaTasa {
    switch (_modo) {
      case 'hoy':
        return _bcvHoy?.fecha;
      case 'registrada':
        final t = _tasaRegistrada;
        return t == null ? null : DateTime.tryParse('${t['fecha']}');
      case 'manual':
        return _fechaManual;
      default:
        return null;
    }
  }

  Future<void> _elegirFechaManual() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaManual,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _fechaManual = d);
  }

  Widget _hoy() {
    if (_cargandoHoy) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorHoy != null) {
      return Column(children: [
        Text(_errorHoy!),
        TextButton.icon(
          onPressed: _cargarHoy,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar BCV'),
        ),
      ]);
    }
    final t = _bcvHoy;
    if (t == null) return const SizedBox.shrink();
    return Text('BCV ${fecha(t.fecha)}: ${t.tasa} Bs/USD');
  }

  Widget _registradas() {
    if (_cargandoTasas) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorTasas != null || _tasas.isEmpty) {
      return Text(_errorTasas ?? 'No hay tasas registradas.');
    }
    return DropdownButtonFormField<int>(
      initialValue: _tasaIndex,
      decoration: const InputDecoration(labelText: 'Tasa registrada'),
      items: [
        for (var i = 0; i < _tasas.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
                '${fecha(DateTime.parse('${_tasas[i]['fecha']}'))} · ${_tasas[i]['tasa']} Bs/USD'),
          ),
      ],
      onChanged: (v) => setState(() => _tasaIndex = v ?? 0),
    );
  }

  Widget _manualForm() => Column(children: [
        TextField(
          controller: _manual,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Tasa (Bs/USD)'),
          onChanged: (_) => setState(() {}),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Fecha: ${fecha(_fechaManual)}'),
          trailing: const Icon(Icons.calendar_month),
          onTap: _elegirFechaManual,
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final nueva = _tasa;
    final fechaNueva = _fechaTasa;
    final actual = widget.nomina.tasaBcv;
    final fechaActual = widget.nomina.tasaFecha;

    return AlertDialog(
      title: const Text('Recalcular nómina'),
      content: SizedBox(
        width: anchoDialogo(context, 440),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Tasa actual: ${actual == null ? '—' : actual.toStringAsFixed(4)} Bs/USD'
              '${fechaActual == null ? '' : ' (${fecha(fechaActual)})'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: const Text('Tasa del día'),
                selected: _modo == 'hoy',
                onSelected: (_) => setState(() => _modo = 'hoy'),
              ),
              ChoiceChip(
                label: const Text('Tasa registrada'),
                selected: _modo == 'registrada',
                onSelected: (_) => setState(() => _modo = 'registrada'),
              ),
              ChoiceChip(
                label: const Text('Manual'),
                selected: _modo == 'manual',
                onSelected: (_) => setState(() => _modo = 'manual'),
              ),
            ]),
            const SizedBox(height: 10),
            if (_modo == 'hoy') _hoy(),
            if (_modo == 'registrada') _registradas(),
            if (_modo == 'manual') _manualForm(),
            const SizedBox(height: 10),
            Text(
              'Nueva tasa: ${nueva == null ? '—' : nueva.toStringAsFixed(4)} Bs/USD'
              '${fechaNueva == null ? '' : ' (${fecha(fechaNueva)})'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Los montos en Bs se reemplazarán usando la nueva tasa. '
              'El estado de la nómina seguirá siendo aprobada.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: nueva != null && nueva > 0 && fechaNueva != null
              ? () => Navigator.pop(
                  context, (tasa: nueva, fecha: fechaNueva))
              : null,
          child: const Text('Recalcular'),
        ),
      ],
    );
  }
}
