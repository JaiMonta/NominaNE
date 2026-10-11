import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/payroll_engine.dart';
import '../models/models.dart';

final db = Supabase.instance.client;
String fecha(DateTime d) => d.toIso8601String().substring(0, 10);
double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

class Repo {
  // ---------- Perfil ----------
  static Future<String> rol() async {
    final u = db.auth.currentUser;
    if (u == null) return 'consulta';
    final r = await db.from('perfiles').select('rol').eq('id', u.id).maybeSingle();
    return (r?['rol'] as String?) ?? 'consulta';
  }

  // ---------- Tasas de cambio (BCV) ----------
  /// Tasa USD más reciente con fecha <= [dia]; null si no hay.
  static Future<double?> tasa(DateTime dia) async {
    final r = await db
        .from('tasas_cambio')
        .select('tasa')
        .eq('moneda', 'USD')
        .lte('fecha', fecha(dia))
        .order('fecha', ascending: false)
        .limit(1)
        .maybeSingle();
    return r == null ? null : _num(r['tasa']);
  }

  static Future<List<Map<String, dynamic>>> tasas() async =>
      List<Map<String, dynamic>>.from(
          await db.from('tasas_cambio').select().order('fecha', ascending: false));

  static Future<void> guardarTasa(DateTime dia, double tasa,
          {String fuente = 'BCV'}) =>
      db.from('tasas_cambio').upsert({
        'fecha': fecha(dia),
        'moneda': 'USD',
        'tasa': tasa,
        'fuente': fuente,
      }, onConflict: 'fecha,moneda');

  // ---------- Ajustes (valores de texto) ----------
  static Future<List<Map<String, dynamic>>> ajustes() async =>
      List<Map<String, dynamic>>.from(
          await db.from('ajustes').select().order('clave'));

  static Future<String> ajuste(String clave) async {
    final r = await db
        .from('ajustes')
        .select('valor')
        .eq('clave', clave)
        .maybeSingle();
    return (r?['valor'] as String?) ?? '';
  }

  static Future<void> guardarAjuste(String clave, String valor) =>
      db.from('ajustes').update({'valor': valor}).eq('clave', clave);

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
  /// Los montos base (salario y novedades) están en USD y se convierten a
  /// Bolívares (VES) con la tasa BCV de la fecha de corte.
  static Future<int> generarNomina({
    required String nombre,
    required String frecuencia,
    required DateTime inicio,
    required DateTime fin,
    double utilidadesDias = 0,
  }) async {
    final tasaBcv = await tasa(fin);
    if (tasaBcv == null || tasaBcv <= 0) {
      throw StateError('No hay tasa BCV cargada para ${fecha(fin)} ni antes. '
          'Regístrela en la pestaña "Tasas".');
    }
    final t = tasaBcv;
    double bs(double usd) => usd * t;

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

    // Los conceptos con cálculo fijo tienen su valor en USD -> a VES.
    final entConceptos = conceptos
        .map((c) {
          final calculo = (c['calculo'] ?? 'manual') as String;
          final valorUsd = _num(c['valor']);
          return EntradaConcepto(
            codigo: c['codigo'],
            nombre: c['nombre'],
            tipo: c['tipo'],
            baseLegal: c['base_legal'],
            esSalarial: c['es_salarial'] ?? true,
            calculo: calculo,
            valor: calculo == 'fijo' ? bs(valorUsd) : valorUsd,
          );
        })
        .toList();

    final nom = await db.from('nominas').insert({
      'nombre': nombre,
      'frecuencia': frecuencia,
      'periodo_inicio': fecha(inicio),
      'periodo_fin': fecha(fin),
      'tasa_bcv': tasaBcv,
      'tasa_fecha': fecha(fin),
      'creada_por': db.auth.currentUser?.id,
    }).select().single();

    double tI = 0, tE = 0, tN = 0, tA = 0;
    for (final e in emps) {
      // Montos de novedades en USD -> VES (0 = lo calcula el motor).
      final novs = nov
          .where((n) => n['empleado_id'] == e.id)
          .map((n) {
            final montoUsd = _num(n['monto_usd']);
            return EntradaNovedad(
              (porId[n['concepto_id']]?['codigo'] ?? '') as String,
              _num(n['cantidad']),
              montoUsd == 0 ? 0 : bs(montoUsd),
            );
          })
          .toList();
      final r = motor.calcular(
        salarioMensual: bs(e.salarioMensualUsd),
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
        'salario_mensual': r2(bs(e.salarioMensualUsd)),
        'salario_mensual_usd': r2(e.salarioMensualUsd),
        'tasa_bcv': tasaBcv,
        'salario_diario': r.salarioDiario,
        'total_ingresos': r.totalIngresos,
        'total_egresos': r.totalEgresos,
        'neto': r.neto,
        'total_ingresos_usd': r2(r.totalIngresos / tasaBcv),
        'total_egresos_usd': r2(r.totalEgresos / tasaBcv),
        'neto_usd': r2(r.neto / tasaBcv),
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
            'monto_usd': r2(l.monto / tasaBcv),
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
