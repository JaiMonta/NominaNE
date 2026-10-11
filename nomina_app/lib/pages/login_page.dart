import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Nómina', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Correo')),
                  TextField(
                      controller: _pass,
                      obscureText: true,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(labelText: 'Contraseña')),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _cargando ? null : _enviar,
                      child: Text(_registro ? 'Registrarme' : 'Entrar')),
                  TextButton(
                      onPressed: () => setState(() => _registro = !_registro),
                      child: Text(_registro
                          ? 'Ya tengo cuenta'
                          : 'Crear cuenta (el primer usuario es administrador)')),
                  if (_msg != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_msg!, style: const TextStyle(color: Colors.red))),
                ]),
              ),
            ),
          ),
        ),
      );
}
