import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/repo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _registro = false, _cargando = false;
  String? _msg;
  String _empresa = 'FÁBRICA DE VELAS NUEVA ERA, C.A.';

  String get _empresaDisplay =>
      _empresa.replaceAll('NUEVA ERA', 'NUEVA\u00A0ERA');

  @override
  void initState() {
    super.initState();
    Repo.ajuste('empresa_nombre').then((v) {
      if (mounted && v.trim().isNotEmpty) setState(() => _empresa = v.trim());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _cargando = true;
      _msg = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_registro) {
        await auth.signUp(email: _email.text.trim(), password: _pass.text);
        _msg = 'Cuenta creada. Si su proyecto exige confirmación, revise su correo.';
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _pass.text);
      }
    } on AuthException catch (e) {
      _msg = e.message;
    } catch (e) {
      _msg = '$e';
    }
    if (mounted) setState(() => _cargando = false);
  }

  Widget _marca(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.asset(
            'assets/branding/Logo2_trim.png',
            width: 160,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _empresaDisplay,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 32,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SISTEMA DE NÓMINA',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.8,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Container(width: 48, height: 1, color: scheme.outlineVariant),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _marca(context),
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Iniciar sesión',
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface)),
                            const SizedBox(height: 4),
                            Text('Ingrese sus credenciales',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 20),
                            TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    const InputDecoration(labelText: 'Correo')),
                            TextField(
                                controller: _pass,
                                obscureText: true,
                                onSubmitted: (_) => _enviar(),
                                decoration: const InputDecoration(
                                    labelText: 'Contraseña')),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                  onPressed: _cargando ? null : _enviar,
                                  child: _cargando
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : Text(_registro ? 'Registrarme' : 'Entrar')),
                            ),
                            TextButton(
                                onPressed: () =>
                                    setState(() => _registro = !_registro),
                                child: Text(_registro
                                    ? 'Ya tengo cuenta'
                                    : 'Crear cuenta (el primer usuario es administrador)')),
                            if (_msg != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(_msg!,
                                      style: TextStyle(
                                          color: scheme.error))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('LOT / LOPCYMAT',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.6,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
