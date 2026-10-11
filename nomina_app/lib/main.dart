import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const NominaApp());
}

class NominaApp extends StatelessWidget {
  const NominaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nómina',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (_, __) => Supabase.instance.client.auth.currentSession == null
              ? const LoginPage()
              : const HomePage(),
        ),
      );
}
