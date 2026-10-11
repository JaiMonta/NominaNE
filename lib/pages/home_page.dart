import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/repo.dart';
import 'conceptos_page.dart';
import 'empleados_page.dart';
import 'nominas_page.dart';
import 'novedades_page.dart';
import 'parametros_page.dart';
import 'tasas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _i = 0;
  String _rol = 'consulta';

  @override
  void initState() {
    super.initState();
    Repo.rol().then((r) => mounted ? setState(() => _rol = r) : null);
  }

  @override
  Widget build(BuildContext context) {
    final puedeEditar = _rol == 'admin' || _rol == 'rrhh';
    final paginas = <Widget>[
      EmpleadosPage(puedeEditar: puedeEditar),
      ConceptosPage(puedeEditar: puedeEditar),
      NovedadesPage(puedeEditar: puedeEditar),
      NominasPage(puedeEditar: puedeEditar),
      ParametrosPage(puedeEditar: puedeEditar),
      TasasPage(puedeEditar: puedeEditar),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nómina · LOT / LOPCYMAT'),
        actions: [
          Center(child: Text(Supabase.instance.client.auth.currentUser?.email ?? '')),
          Chip(label: Text(_rol)),
          IconButton(
              tooltip: 'Salir',
              icon: const Icon(Icons.logout),
              onPressed: () => Supabase.instance.client.auth.signOut()),
        ],
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.people), label: Text('Empleados')),
            NavigationRailDestination(icon: Icon(Icons.list_alt), label: Text('Conceptos')),
            NavigationRailDestination(icon: Icon(Icons.edit_note), label: Text('Novedades')),
            NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Nóminas')),
            NavigationRailDestination(icon: Icon(Icons.gavel), label: Text('Parámetros')),
            NavigationRailDestination(icon: Icon(Icons.currency_exchange), label: Text('Tasas')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: paginas[_i]),
      ]),
    );
  }
}
