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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Repo.rol().then((r) => mounted ? setState(() => _rol = r) : null);
  }

  @override
  Widget build(BuildContext context) {
    final puedeEditar = _rol == 'admin' || _rol == 'rrhh';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final destinos = <(IconData, String)>[
      (Icons.people, 'Empleados'),
      (Icons.list_alt, 'Conceptos'),
      (Icons.edit_note, 'Novedades'),
      (Icons.payments, 'Nóminas'),
      (Icons.gavel, 'Parámetros'),
      (Icons.currency_exchange, 'Tasas'),
    ];
    final paginas = <Widget>[
      EmpleadosPage(puedeEditar: puedeEditar),
      ConceptosPage(puedeEditar: puedeEditar),
      NovedadesPage(puedeEditar: puedeEditar),
      NominasPage(puedeEditar: puedeEditar),
      ParametrosPage(puedeEditar: puedeEditar),
      TasasPage(puedeEditar: puedeEditar),
    ];

    return LayoutBuilder(builder: (context, c) {
      final esMovil = c.maxWidth < 800;
      final body = esMovil
          ? paginas[_i]
          : Row(children: [
              NavigationRail(
                selectedIndex: _i,
                onDestinationSelected: (v) => setState(() => _i = v),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinos)
                    NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: paginas[_i]),
            ]);
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Nómina · LOT / LOPCYMAT'),
          leading: esMovil
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer())
              : null,
          actions: [
            if (!esMovil)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(email))),
            Chip(label: Text(_rol)),
            IconButton(
                tooltip: 'Salir',
                icon: const Icon(Icons.logout),
                onPressed: () => Supabase.instance.client.auth.signOut()),
          ],
        ),
        drawer: esMovil
            ? Drawer(
                child: SafeArea(
                  child: ListView(
                    children: [
                      DrawerHeader(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Nómina',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(email, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Chip(label: Text(_rol)),
                          ],
                        ),
                      ),
                      for (var i = 0; i < destinos.length; i++)
                        ListTile(
                          selected: _i == i,
                          leading: Icon(destinos[i].$1),
                          title: Text(destinos[i].$2),
                          onTap: () {
                            setState(() => _i = i);
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                ),
              )
            : null,
        body: body,
      );
    });
  }
}
