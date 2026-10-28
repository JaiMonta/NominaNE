import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/asistencia_service.dart';
import '../services/repo.dart';

class AsistenciaPublicaPage extends StatefulWidget {
  final String token;

  const AsistenciaPublicaPage({super.key, required this.token});

  @override
  State<AsistenciaPublicaPage> createState() => _AsistenciaPublicaPageState();
}

class _AsistenciaPublicaPageState extends State<AsistenciaPublicaPage> {
  final _cedula = TextEditingController();
  final _pin = TextEditingController();
  Timer? _timer;
  DateTime _ahora = DateTime.now();
  String _empresa = 'FÁBRICA DE VELAS NUEVA ERA, C.A.';
  bool _validando = true;
  bool _qrValido = false;
  bool _busy = false;
  String? _error;
  String? _ok;
  String? _okNombre;
  String? _okTipo;
  DateTime? _okHora;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final nombre = await Repo.ajuste('empresa_nombre');
      if (mounted && nombre.trim().isNotEmpty) {
        setState(() => _empresa = nombre.trim());
      }
    } catch (_) {}

    try {
      final ok = await AsistenciaService.validarQr(widget.token);
      if (mounted) {
        setState(() {
          _qrValido = ok;
          _validando = false;
          _error = ok ? null : 'QR vencido o inválido. Solicite el QR del día a RRHH.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _qrValido = false;
          _validando = false;
          _error = 'No se pudo validar el QR. Intente de nuevo.';
        });
      }
    }
  }

  Future<void> _registrar(String tipo) async {
    final cedula = _cedula.text.replaceAll(RegExp(r'\D'), '');
    final pin = _pin.text.trim();
    if (cedula.isEmpty || pin.isEmpty) {
      setState(() => _error = 'Ingrese cédula y PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });

    try {
      final res = await AsistenciaService.registrar(
        token: widget.token,
        cedula: cedula,
        pin: pin,
        tipo: tipo,
      );
      if (!mounted) return;

      if (res['ok'] == true) {
        final hora = res['hora'] == null
            ? DateTime.now()
            : DateTime.parse(res['hora']).toLocal();
        setState(() {
          _ok = tipo == 'entrada' ? 'Entrada registrada' : 'Salida registrada';
          _okNombre = res['nombre']?.toString();
          _okTipo = tipo;
          _okHora = hora;
          _pin.clear();
          _busy = false;
        });
      } else {
        setState(() {
          _error = res['error']?.toString() ?? 'No se pudo registrar.';
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo registrar. Intente de nuevo.';
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cedula.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/branding/Logo2_trim.png',
                          width: 150,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _empresa,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registro de asistencia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es')
                            .format(_ahora),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        DateFormat('hh:mm:ss a').format(_ahora),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      if (_validando)
                        const Center(child: CircularProgressIndicator())
                      else if (!_qrValido)
                        _avisoQr(context)
                      else
                        _formulario(context, scheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avisoQr(BuildContext context) => Column(
        children: [
          Icon(Icons.qr_code_2,
              size: 52, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text(
            _error ?? 'QR vencido o inválido.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _validando = true;
                _error = null;
              });
              _cargar();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );

  Widget _formulario(BuildContext context, ColorScheme scheme) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_ok != null) ...[_exito(context), const SizedBox(height: 14)],
          TextField(
            controller: _cedula,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Cédula',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'PIN de asistencia',
              prefixIcon: Icon(Icons.lock_outline),
              counterText: '',
            ),
            onSubmitted: (_) => _busy ? null : _registrar('entrada'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _registrar('entrada'),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Registrar entrada'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _registrar('salida'),
            icon: const Icon(Icons.logout),
            label: const Text('Registrar salida'),
          ),
          const SizedBox(height: 12),
          Text(
            'La hora la registra el servidor. No comparta su PIN. '
            'Si no lo tiene, consulte a RRHH.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  Widget _exito(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary, size: 30),
            const SizedBox(height: 6),
            Text(
              _ok!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_okNombre != null) Text(_okNombre!),
            if (_okHora != null)
              Text(
                '${_okTipo == 'entrada' ? 'Entrada' : 'Salida'}: '
                '${DateFormat('hh:mm:ss a').format(_okHora!)}',
              ),
          ],
        ),
      );
}
