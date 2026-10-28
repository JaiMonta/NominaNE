import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/asistencia_pdf_service.dart';
import '../services/asistencia_service.dart';
import '../services/repo.dart';

final _fechaCorta = DateFormat('dd/MM/yyyy');
final _horaCorta = DateFormat('hh:mm a');

String _fechaTexto(DateTime d) => _fechaCorta.format(d);
String _horaTexto(DateTime? d) => d == null ? '—' : _horaCorta.format(d);

String _horasTexto(AsistenciaDia? a) {
  if (a == null || a.entrada == null || a.salida == null) return '—';
  final total = a.horas;
  final h = total.floor();
  final m = ((total - h) * 60).round();
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String _errorTexto(Object x) =>
    x is PostgrestException ? x.message : x.toString();

Widget _stat(BuildContext context, String label, String value, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Text(label),
      ]),
    );

class AsistenciaPage extends StatelessWidget {
  final bool puedeEditar;

  const AsistenciaPage({super.key, required this.puedeEditar});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'Día'), Tab(text: 'Mes')]),
          Expanded(
            child: TabBarView(children: [
              _DiaTab(puedeEditar: puedeEditar),
              const _MesTab(),
            ]),
          ),
        ]),
      );
}

class _DiaTab extends StatefulWidget {
  final bool puedeEditar;

  const _DiaTab({required this.puedeEditar});

  @override
  State<_DiaTab> createState() => _DiaTabState();
}

class _DiaTabState extends State<_DiaTab> {
  DateTime _fecha = DateTime.now();
  late Future<_DatosDia> _f = _cargar();

  Future<_DatosDia> _cargar() async {
    final empleados = await Repo.empleados();
    final asistencias = await AsistenciaService.asistenciasDelDia(_fecha);
    final pines = widget.puedeEditar
        ? await AsistenciaService.pinesAsignados()
        : <String>{};

    QrAsistencia? qr;
    String? qrError;
    if (widget.puedeEditar) {
      try {
        qr = await AsistenciaService.crearQr();
      } catch (x) {
        qrError = _errorTexto(x);
      }
    }

    return _DatosDia(
      empleados: empleados,
      asistencias: {for (final a in asistencias) a.empleadoId: a},
      pines: pines,
      qr: qr,
      qrError: qrError,
    );
  }

  void _reload() => setState(() => _f = _cargar());

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _fecha = d;
        _f = _cargar();
      });
    }
  }

  Future<DateTime?> _elegirFechaHora(DateTime inicial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null) return null;
    if (!mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _copiar(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    _snack('Enlace copiado.');
  }

  Future<void> _regenerar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerar QR'),
        content: const Text(
            'El QR actual dejará de funcionar. ¿Desea generar uno nuevo para hoy?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AsistenciaService.crearQr(reemplazar: true);
      _reload();
      _snack('QR regenerado.');
    } catch (x) {
      _snack(_errorTexto(x), error: true);
    }
  }

  Future<void> _manual(Empleado e, String tipo) async {
    final ahora = DateTime.now();
    final inicial = tipo == 'entrada'
        ? DateTime(_fecha.year, _fecha.month, _fecha.day, ahora.hour, ahora.minute)
        : ahora;
    final hora = await _elegirFechaHora(inicial);
    if (hora == null) return;

    try {
      await AsistenciaService.registrarManual(
        empleadoId: e.id!,
        fecha: tipo == 'entrada'
            ? DateTime(hora.year, hora.month, hora.day)
            : _fecha,
        tipo: tipo,
        hora: hora,
      );
      _reload();
      _snack(
          '${tipo == 'entrada' ? 'Entrada' : 'Salida'} registrada para ${e.nombreCompleto}.');
    } catch (x) {
      _snack(_errorTexto(x), error: true);
    }
  }

  Future<void> _corregir(Empleado e, AsistenciaDia a) async {
    if (a.id == null) return;
    var entrada = a.entrada;
    var salida = a.salida;
    final nota = TextEditingController(text: a.nota ?? '');
    final inicialEntrada =
        entrada ?? DateTime(a.fecha.year, a.fecha.month, a.fecha.day, 8, 0);
    final inicialSalida = salida ??
        entrada ??
        DateTime(a.fecha.year, a.fecha.month, a.fecha.day, 17, 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Corregir · ${e.nombreCompleto}'),
          content: SizedBox(
            width: anchoDialogo(context, 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Entrada: ${_horaTexto(entrada)}'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final d = await _elegirFechaHora(inicialEntrada);
                  if (d != null) setLocal(() => entrada = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Salida: ${_horaTexto(salida)}'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final d = await _elegirFechaHora(inicialSalida);
                  if (d != null) setLocal(() => salida = d);
                },
              ),
              TextField(
                controller: nota,
                decoration: const InputDecoration(labelText: 'Nota'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (ok != true) {
      nota.dispose();
      return;
    }

    try {
      await AsistenciaService.corregir(
        id: a.id!,
        entrada: entrada,
        salida: salida,
        nota: nota.text.trim().isEmpty ? null : nota.text.trim(),
      );
      _reload();
      _snack('Registro corregido.');
    } catch (x) {
      _snack(_errorTexto(x), error: true);
    } finally {
      nota.dispose();
    }
  }

  Future<void> _pinDialog(Empleado e, bool tienePin) async {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('PIN de asistencia · ${e.nombreCompleto}'),
          content: SizedBox(
            width: anchoDialogo(context, 380),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                tienePin
                    ? 'Ya tiene un PIN. Si asigna otro, se reemplaza.'
                    : 'Asigne un PIN de 4 a 6 dígitos y comuníqueselo al empleado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setLocal(() =>
                      pin.text = (1000 + Random().nextInt(9000)).toString()),
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Generar'),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (ok != true) {
      pin.dispose();
      return;
    }

    final valor = pin.text.trim();
    if (!RegExp(r'^[0-9]{4,6}$').hasMatch(valor)) {
      _snack('El PIN debe tener entre 4 y 6 dígitos.', error: true);
      pin.dispose();
      return;
    }

    try {
      await AsistenciaService.asignarPin(e.id!, valor);
      _reload();
      _snack('PIN asignado. Comuníquelo al empleado.');
    } catch (x) {
      _snack(_errorTexto(x), error: true);
    } finally {
      pin.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosDia>(
      future: _f,
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = s.data!;
        final empleados = d.empleados
            .where((e) => e.activo || d.asistencias.containsKey(e.id))
            .toList()
          ..sort((a, b) => a.nombreCompleto
              .toLowerCase()
              .compareTo(b.nombreCompleto.toLowerCase()));

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFecha,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Fecha: ${_fechaTexto(_fecha)}'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _fecha = DateTime.now();
                      _f = _cargar();
                    });
                  },
                  child: const Text('Hoy'),
                ),
              ]),
              if (widget.puedeEditar) ...[
                const SizedBox(height: 10),
                _qrPanel(context, d),
              ],
              _resumen(context, d),
              if (empleados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Sin empleados')),
                ),
              for (final e in empleados) _empleadoCard(context, d, e),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _qrPanel(BuildContext context, _DatosDia d) {
    final scheme = Theme.of(context).colorScheme;
    if (d.qrError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('No se pudo generar el QR: ${d.qrError}',
                style: TextStyle(color: scheme.error)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
      );
    }

    final qr = d.qr;
    if (qr == null) return const SizedBox.shrink();
    final url = Uri.parse('${Uri.base.origin}/?asistencia=${qr.token}').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Icon(Icons.qr_code_2, color: scheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('QR del día',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text(_fechaTexto(qr.fecha),
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 6),
          Text('Válido para hoy hasta las 11:59 p.m.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(url,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _copiar(url),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar enlace'),
            ),
            FilledButton.tonalIcon(
              onPressed: _regenerar,
              icon: const Icon(Icons.autorenew),
              label: const Text('Regenerar'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _resumen(BuildContext context, _DatosDia d) {
    final activos = d.empleados.where((e) => e.activo).toList();
    final presentes = activos
        .where((e) => d.asistencias[e.id]?.entrada != null)
        .length;
    final pendientes =
        activos.where((e) => d.asistencias[e.id]?.pendiente == true).length;
    final sinRegistro =
        activos.where((e) => d.asistencias[e.id] == null).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        _stat(context, 'Presentes', '$presentes', Paleta.ingreso),
        _stat(context, 'Sin salida', '$pendientes', Colors.orange),
        _stat(context, 'Sin registro', '$sinRegistro',
            Theme.of(context).colorScheme.outline),
      ]),
    );
  }

  Widget _empleadoCard(BuildContext context, _DatosDia d, Empleado e) {
    final a = d.asistencias[e.id];
    final scheme = Theme.of(context).colorScheme;
    final estado = a == null
        ? 'Sin registro'
        : (a.pendiente ? 'En turno' : 'Completado');
    final color = a == null
        ? scheme.outline
        : (a.pendiente ? Colors.orange : Paleta.ingreso);
    final tienePin = d.pines.contains(e.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${e.cedula} · ${e.departamento ?? 'Sin departamento'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(estado),
              side: BorderSide(color: color),
              backgroundColor: color.withValues(alpha: 0.08),
            ),
            if (widget.puedeEditar)
              IconButton(
                tooltip: 'Asignar PIN',
                icon: Icon(
                  tienePin ? Icons.lock : Icons.lock_open,
                  color: tienePin ? Paleta.ingreso : scheme.error,
                ),
                onPressed: () => _pinDialog(e, tienePin),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Entrada: ${_horaTexto(a?.entrada)}   ·   '
            'Salida: ${_horaTexto(a?.salida)}   ·   '
            'Horas: ${_horasTexto(a)}',
          ),
          if (a?.nota != null && a!.nota!.trim().isNotEmpty)
            Text('Nota: ${a.nota}',
                style: Theme.of(context).textTheme.bodySmall),
          if (widget.puedeEditar) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (a == null || a.entrada == null)
                OutlinedButton.icon(
                  onPressed: () => _manual(e, 'entrada'),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Entrada'),
                )
              else if (a.salida == null)
                OutlinedButton.icon(
                  onPressed: () => _manual(e, 'salida'),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Salida'),
                ),
              if (a != null)
                TextButton.icon(
                  onPressed: () => _corregir(e, a),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Corregir'),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _DatosDia {
  final List<Empleado> empleados;
  final Map<String, AsistenciaDia> asistencias;
  final Set<String> pines;
  final QrAsistencia? qr;
  final String? qrError;

  const _DatosDia({
    required this.empleados,
    required this.asistencias,
    required this.pines,
    required this.qr,
    required this.qrError,
  });
}

class _MesTab extends StatefulWidget {
  const _MesTab();

  @override
  State<_MesTab> createState() => _MesTabState();
}

class _MesTabState extends State<_MesTab> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<_DatosMes> _f = _cargar();

  Future<_DatosMes> _cargar() async {
    final empleados = await Repo.empleados();
    final inicio = DateTime(_mes.year, _mes.month, 1);
    final fin = DateTime(_mes.year, _mes.month + 1, 0);
    final asistencias =
        await AsistenciaService.asistenciasEntre(inicio, fin);
    final empresa = await Repo.ajuste('empresa_nombre');
    return _DatosMes(
      empleados: empleados,
      asistencias: asistencias,
      empresa: empresa,
    );
  }

  void _reload() => setState(() => _f = _cargar());

  Future<void> _pickMes() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _mes,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _mes = DateTime(d.year, d.month);
        _f = _cargar();
      });
    }
  }

  List<ResumenAsistencia> _filas(_DatosMes d) {
    final empleados = d.empleados
        .where((e) =>
            e.activo || d.asistencias.any((a) => a.empleadoId == e.id))
        .toList()
      ..sort((a, b) => a.nombreCompleto
          .toLowerCase()
          .compareTo(b.nombreCompleto.toLowerCase()));

    final filas = <ResumenAsistencia>[];
    for (final e in empleados) {
      final registros =
          d.asistencias.where((a) => a.empleadoId == e.id).toList();
      final dias = registros.where((a) => a.entrada != null).length;
      final horas = registros.fold<double>(0, (s, a) => s + a.horas);
      final pendientes = registros.where((a) => a.pendiente).length;
      filas.add(ResumenAsistencia(
        empleado: e.nombreCompleto,
        cedula: e.cedula,
        departamento: e.departamento ?? 'Sin departamento',
        dias: dias,
        horas: horas,
        pendientes: pendientes,
      ));
    }
    return filas;
  }

  Future<void> _exportar(_DatosMes d, List<ResumenAsistencia> filas) async {
    try {
      await emitirAsistenciaMes(
        empresa: d.empresa.trim().isEmpty ? 'Nómina' : d.empresa.trim(),
        mes: _mes,
        filas: filas,
      );
    } catch (x) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo generar el PDF: ${_errorTexto(x)}'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosMes>(
      future: _f,
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = s.data!;
        final filas = _filas(d);
        final total = filas.fold<double>(0, (s, f) => s + f.horas);
        final conRegistro = filas.where((f) => f.dias > 0).length;
        final pendientes = filas.fold<int>(0, (s, f) => s + f.pendientes);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMes,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                        DateFormat('MMMM yyyy', 'es').format(_mes)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _exportar(d, filas),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _stat(context, 'Horas del mes', total.toStringAsFixed(2),
                    Theme.of(context).colorScheme.primary),
                _stat(context, 'Con registro', '$conRegistro', Paleta.ingreso),
                _stat(context, 'Salidas pendientes', '$pendientes',
                    Colors.orange),
              ]),
              const SizedBox(height: 8),
              if (filas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Sin registros en el mes')),
                ),
              for (final f in filas)
                Card(
                  child: ListTile(
                    title: Text(f.empleado),
                    subtitle: Text('${f.cedula} · ${f.departamento}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${f.dias} días',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${f.horas.toStringAsFixed(2)} h',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (f.pendientes > 0)
                          Text('${f.pendientes} pend.',
                              style: const TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class _DatosMes {
  final List<Empleado> empleados;
  final List<AsistenciaDia> asistencias;
  final String empresa;

  const _DatosMes({
    required this.empleados,
    required this.asistencias,
    required this.empresa,
  });
}
