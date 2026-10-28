import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/asistencia_url.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'pages/asistencia_publica_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(NominaApp(asistenciaToken: tokenAsistenciaDesde(Uri.base)));
}

class NominaApp extends StatelessWidget {
  final String? asistenciaToken;

  const NominaApp({super.key, this.asistenciaToken});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: modoTema,
        builder: (_, modo, __) => MaterialApp(
          title: 'Nómina',
          debugShowCheckedModeBanner: false,
          theme: appLight,
          darkTheme: appDark,
          themeMode: modo,
          home: asistenciaToken != null
              ? AsistenciaPublicaPage(token: asistenciaToken!)
              : StreamBuilder<AuthState>(
                  stream: Supabase.instance.client.auth.onAuthStateChange,
                  builder: (_, __) =>
                      Supabase.instance.client.auth.currentSession == null
                          ? const LoginPage()
                          : const HomePage(),
                ),
        ),
      );
}
