import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/payroll_engine.dart';
import '../models/models.dart';

final db = Supabase.instance.client;
String fecha(DateTime d) => d.toIso8601String().substring(0, 10);

class Repo {
  // ---------- Perfil ----------
  static Future<String> rol() async {
    final u = db.auth.currentUser;
    if (u == null) return 'consulta';
    final r = await db.from('perfiles').select('rol').eq('id', u.id).maybeSingle();
    return (r?['rol'] as String?) ?? 'consulta';
  }

  // ---------- Parámetros ----------
  static Future<List<Map<String, dynamic>>> parametros() async =>
      List<Map<String, dynamic>>.from(
          await db.from('parametros_legales').select().order('clave'));

  static Future<Map<String, double>> parametrosMapa() async => {
        for (final r in await parametros())
          r['clave'] as String: (r['valor'] as num).toDouble()
      };

  static Future<void> guardarParametro(String clave, double valor) =>
      db.from('parametros_legales').update({'valor': valor}).eq('clave', clave);

  // ---------- Empleados ----------
  static Future<List<Empleado>> empleados() async =>
      (await db.from('empleados').select().order('apellidos'))
          .map<Empleado>((j) => Empleado.fromJson(j))
          .toList();

  static Future<void> guardarEmpleado(Empleado e) async {
    if (e.id == null) {
      await db.from('empleados').insert(e.toJson());
    } else {
      await db.from('empleados').update(e.toJson()).eq('id', e.id!);
    }
  }

  // ---------- Conceptos ----------
  static Future<List<Concepto>> conceptos() async =>
      (await db.from('conceptos').select().order('tipo').order('codigo'))
          .map<Concepto>((j) => Concepto.fromJson(j))
          .toList();

  static Future<void> guardarConcepto(Concepto c) async {
    if (c.id == null) {
      await db.from('conceptos').insert(c.toJson());
    } else {
      await db.from('conceptos').update(c.toJson()).eq('id', c.id!);
    }
  }

  // ---------- Novedades ----------
  static Future<List<Map<String, dynamic>>> novedades() async =>
      List<Map<String, dynamic>>.from(await db
          .from('novedades')
          .select('*, empleados(nombres,apellidos), conceptos(codigo,nombre,tipo)')
          .order('created_at', ascending: false));

  static Future<void> agregarNovedad(Map<String, dynamic> n) =>
      db.from('novedades').insert(n);

  static Future<void> borrarNovedad(String id) =>
      db.from('novedades').delete().eq('id', id);

  // ---------- Nóminas ----------
  static Future<List<Nomina>> nominas() async =>
      (await db.from('nominas').select().order('created_at', ascending: false))
          .map<Nomina>((j) => Nomina.fromJson(j))
          .toList();

  static Future<List<Recibo>> recibos(String nominaId) async =>
      (await db
              .from('recibos')
              .select('*, empleados(nombres,apellidos,cedula)')
              .eq('nomina_id', nominaId))
          .map<Recibo>((j) => Recibo.fromJson(j))
          .toList();

  static Future<List<Map<String, dynamic>>> detalle(String reciboId) async =>
      List<Map<String, dynamic>>.from(await db
          .from('recibo_detalle')
          .select()
          .eq('recibo_id', reciboId)
          .order('tipo', ascending: false));

  static Future<void> cambiarEstado(String id, String estado) =>
      db.from('nominas').update({'estado': estado}).eq('id', id);

  static Future<void> borrarNomina(String id) =>
      db.from('nominas').delete().eq('id', id);

  /// Genera la nómina del período: calcula un recibo por empleado activo.
  static Future<int> generarNomina({
    required String nombre,
    required String frecuencia,
    required DateTime inicio,
    required DateTime fin,
    double utilidadesDias = 0,
  }) async {
    final params = await parametrosMapa();
    final motor = PayrollEngine(params);
    final conceptos = await conceptos_();
    final porId = {for (final c in conceptos) c['id'] as String: c};
    final emps = (await empleados())
        .where((e) => e.activo && e.frecuenciaPago == frecuencia)
        .where((e) => !e.fechaIngreso.isAfter(fin))
        .where((e) => e.fechaEgreso == null || !e.fechaEgreso!.isBefore(inicio))
        .toList();
    if (emps.isEmpty) return 0;

    final nov = List<Map<String, dynamic>>.from(await db
        .from('novedades')
        .select()
        .or('periodo_inicio.is.null,and(periodo_inicio.gte.${fecha(inicio)},periodo_inicio.lte.${fecha(fin)})'));

    final entConceptos = conceptos
        .map((c) => EntradaConcepto(
              codigo: c['codigo'],
              nombre: c['nombre'],
              tipo: c['tipo'],
              baseLegal: c['base_legal'],
              esSalarial: c['es_salarial'] ?? true,
              calculo: c['calculo'] ?? 'manual',
              valor: ((c['valor'] ?? 0) as num).toDouble(),
            ))
        .toList();

    final nom = await db.from('nominas').insert({
      'nombre': nombre,
      'frecuencia': frecuencia,
      'periodo_inicio': fecha(inicio),
      'periodo_fin': fecha(fin),
      'creada_por': db.auth.currentUser?.id,
    }).select().single();

    double tI = 0, tE = 0, tN = 0, tA = 0;
    for (final e in emps) {
      final novs = nov
          .where((n) => n['empleado_id'] == e.id)
          .map((n) => EntradaNovedad(
                (porId[n['concepto_id']]?['codigo'] ?? '') as String,
                ((n['cantidad'] ?? 0) as num).toDouble(),
                ((n['monto'] ?? 0) as num).toDouble(),
              ))
          .toList();
      final r = motor.calcular(
        salarioMensual: e.salarioMensual,
        frecuencia: frecuencia,
        ingreso: e.fechaIngreso,
        periodoFin: fin,
        conceptos: entConceptos,
        novedades: novs,
        aplicarUtilidadesDias: utilidadesDias,
      );
      final rec = await db.from('recibos').insert({
        'nomina_id': nom['id'],
        'empleado_id': e.id,
        'salario_mensual': e.salarioMensual,
        'salario_diario': r.salarioDiario,
        'total_ingresos': r.totalIngresos,
        'total_egresos': r.totalEgresos,
        'neto': r.neto,
        'aportes_patronales': r.aportesPatronales,
      }).select().single();
      await db.from('recibo_detalle').insert([
        for (final l in r.lineas)
          {
            'recibo_id': rec['id'],
            'concepto_codigo': l.codigo,
            'concepto_nombre': l.nombre,
            'tipo': l.tipo,
            'cantidad': l.cantidad,
            'monto': l.monto,
            'base_legal': l.baseLegal,
          }
      ]);
      tI += r.totalIngresos;
      tE += r.totalEgresos;
      tN += r.neto;
      tA += r.aportesPatronales;
    }
    await db.from('nominas').update({
      'total_ingresos': r2(tI),
      'total_egresos': r2(tE),
      'total_neto': r2(tN),
      'total_aportes_patronales': r2(tA),
    }).eq('id', nom['id']);
    return emps.length;
  }

  static Future<List<Map<String, dynamic>>> conceptos_() async =>
      List<Map<String, dynamic>>.from(
          await db.from('conceptos').select().eq('activo', true));
}
