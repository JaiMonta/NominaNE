import '../core/liquidacion_engine.dart';
import '../models/liquidacion_models.dart';
import 'repo.dart';

class LiquidacionRepo {
  static Future<List<Liquidacion>> liquidaciones() async =>
      List<Map<String, dynamic>>.from(
              await db.from('liquidaciones').select().order('created_at',
                  ascending: false))
          .map<Liquidacion>((j) => Liquidacion.fromJson(j))
          .toList();

  static Future<List<LiquidacionDetalle>> detalle(String liquidacionId) async =>
      List<Map<String, dynamic>>.from(await db
              .from('liquidacion_detalle')
              .select()
              .eq('liquidacion_id', liquidacionId)
              .order('orden'))
          .map<LiquidacionDetalle>((j) => LiquidacionDetalle.fromJson(j))
          .toList();

  static Future<Liquidacion> guardar(
      Liquidacion liquidacion, List<LiquidacionDetalle> detalles) async {
    Map<String, dynamic> saved;
    if (liquidacion.id == null) {
      saved = await db
          .from('liquidaciones')
          .insert(liquidacion.toJson())
          .select()
          .single();
    } else {
      saved = await db
          .from('liquidaciones')
          .update(liquidacion.toJson())
          .eq('id', liquidacion.id!)
          .select()
          .single();
      await db
          .from('liquidacion_detalle')
          .delete()
          .eq('liquidacion_id', liquidacion.id!);
    }
    final id = saved['id'] as String;
    if (detalles.isNotEmpty) {
      await db.from('liquidacion_detalle').insert([
        for (final d in detalles) {...d.toJson(), 'liquidacion_id': id}
      ]);
    }
    return Liquidacion.fromJson(saved);
  }

  static Future<void> aprobar(String id) =>
      db.rpc('aprobar_liquidacion', params: {'p_liquidacion_id': id});

  static Future<void> anular(String id) =>
      db.rpc('anular_liquidacion', params: {'p_liquidacion_id': id});

  static Future<void> pagar(String id) =>
      db.rpc('pagar_liquidacion', params: {'p_liquidacion_id': id});

  static Future<void> eliminar(String id) =>
      db.from('liquidaciones').delete().eq('id', id);

  static Future<PrestacionesConfig> config(String empleadoId,
      DateTime fechaIngreso) async {
    final r = await db
        .from('prestaciones_config')
        .select()
        .eq('empleado_id', empleadoId)
        .order('vigente_desde', ascending: false)
        .limit(1)
        .maybeSingle();
    if (r != null) return PrestacionesConfig.fromJson(r);
    final nueva = PrestacionesConfig(
        empleadoId: empleadoId, vigenteDesde: fechaIngreso);
    await guardarConfig(nueva);
    return nueva;
  }

  static Future<void> guardarConfig(PrestacionesConfig c) =>
      db.from('prestaciones_config').upsert(c.toJson(),
          onConflict: 'empleado_id,vigente_desde');

  static Future<List<PrestacionesMovimiento>> movimientos(
          String empleadoId) async =>
      List<Map<String, dynamic>>.from(await db
              .from('prestaciones_movimientos')
              .select()
              .eq('empleado_id', empleadoId)
              .order('fecha'))
          .map<PrestacionesMovimiento>((j) =>
              PrestacionesMovimiento.fromJson(j))
          .toList();

  static Future<void> guardarMovimiento(PrestacionesMovimiento m) async {
    if (m.id == null) {
      await db.from('prestaciones_movimientos').insert(m.toJson());
    } else {
      await db
          .from('prestaciones_movimientos')
          .update(m.toJson())
          .eq('id', m.id!);
    }
  }

  static Future<void> eliminarMovimiento(String id) =>
      db.from('prestaciones_movimientos').delete().eq('id', id);

  static Future<List<TasaInteresPrestaciones>> tasas() async =>
      List<Map<String, dynamic>>.from(
              await db.from('tasas_interes_prestaciones').select().order('periodo'))
          .map<TasaInteresPrestaciones>(
              (j) => TasaInteresPrestaciones.fromJson(j))
          .toList();

  static Future<void> guardarTasa(TasaInteresPrestaciones t) =>
      db.from('tasas_interes_prestaciones').upsert(t.toJson(),
          onConflict: 'periodo');

  static Future<List<VacacionesPeriodo>> vacaciones(String empleadoId) async =>
      List<Map<String, dynamic>>.from(await db
              .from('vacaciones_registro')
              .select()
              .eq('empleado_id', empleadoId)
              .order('periodo_inicio'))
          .map<VacacionesPeriodo>((j) => VacacionesPeriodo.fromJson(j))
          .toList();

  static Future<void> guardarVacacion(VacacionesPeriodo v) async {
    if (v.id == null) {
      await db.from('vacaciones_registro').insert(v.toJson());
    } else {
      await db
          .from('vacaciones_registro')
          .update(v.toJson())
          .eq('id', v.id!);
    }
  }

  static Future<int> generarVacaciones(String empleadoId) async {
    final r = await db.rpc('inicializar_vacaciones',
        params: {'p_empleado_id': empleadoId});
    return (r as num?)?.toInt() ?? 0;
  }

  static Future<int> generarPrestaciones(
      String empleadoId, DateTime hasta) async {
    final empleados = await Repo.empleados();
    final empleado = empleados.firstWhere((e) => e.id == empleadoId);
    final params = await Repo.parametrosMapa();
    final cfg = await config(empleadoId, empleado.fechaIngreso);
    final movs = await movimientos(empleadoId);
    final recibo = await ultimoRecibo(empleadoId);
    final tasa = await Repo.tasa(hasta) ?? 0;
    var normal = (recibo?['salario_mensual'] as num?)?.toDouble() ?? 0;
    if (normal <= 0 && tasa > 0) normal = empleado.salarioMensualUsd * tasa;
    if (normal <= 0) return 0;

    final p = ParametrosLiquidacion.fromMap(params);
    final engine = LiquidacionEngine(p);
    final anios = engine.aniosCompletos(empleado.fechaIngreso, hasta);
    final diasBono = engine.diasBonoAnio(anios + 1);
    final utilidades = (params['dias_utilidades_empresa'] ?? 30)
        .clamp(30.0, 120.0);
    final normalDiario = normal / p.diasMes;
    final integral = normalDiario +
        normalDiario * diasBono / p.salarioIntegralDivisor +
        normalDiario * utilidades / p.salarioIntegralDivisor;

    final saldoInicial = movs
        .where((m) => m.tipo == 'saldo_inicial')
        .fold<PrestacionesMovimiento?>(
            null,
            (prev, m) =>
                prev == null || m.fecha.isAfter(prev.fecha) ? m : prev);
    final desde = saldoInicial?.fecha ?? empleado.fechaIngreso;
    final existentes = {
      for (final m in movs)
        if (m.periodo != null)
          '${m.tipo}|${m.periodo!.toIso8601String().substring(0, 10)}'
    };
    var creados = 0;

    var n = 0;
    while (true) {
      final inicioTrimestre =
          _sumarMeses(empleado.fechaIngreso, n * 3);
      if (inicioTrimestre.isAfter(hasta)) break;
      final clave =
          'garantia_trimestral|${inicioTrimestre.toIso8601String().substring(0, 10)}';
      if (!inicioTrimestre.isBefore(desde) && !existentes.contains(clave)) {
        await guardarMovimiento(PrestacionesMovimiento(
          empleadoId: empleadoId,
          fecha: inicioTrimestre,
          periodo: inicioTrimestre,
          tipo: 'garantia_trimestral',
          dias: p.prestacionesDiasTrimestre,
          salarioIntegral: integral,
          monto: p.prestacionesDiasTrimestre * integral,
          modalidad: cfg.modalidad,
          nota: 'Generado con salario actual; ajuste si hubo cambios',
        ));
        creados++;
      }
      n++;
    }

    for (var anio = 2; anio <= anios; anio++) {
      final aniversario = _sumarMeses(empleado.fechaIngreso, 12 * (anio - 1));
      if (aniversario.isAfter(hasta) || aniversario.isBefore(desde)) continue;
      final dias = (p.prestacionesDiasAnioExtra * (anio - 1))
          .clamp(0.0, p.prestacionesDiasExtraMax);
      final clave =
          'dias_adicionales|${aniversario.toIso8601String().substring(0, 10)}';
      if (existentes.contains(clave)) continue;
      await guardarMovimiento(PrestacionesMovimiento(
        empleadoId: empleadoId,
        fecha: aniversario,
        periodo: aniversario,
        tipo: 'dias_adicionales',
        dias: dias,
        salarioIntegral: integral,
        monto: dias * integral,
        modalidad: cfg.modalidad,
        nota: 'Días adicionales generados con salario actual',
      ));
      creados++;
    }

    return creados;
  }

  static DateTime _sumarMeses(DateTime d, int meses) {
    final total = d.month - 1 + meses;
    final y = d.year + total ~/ 12;
    final m = total % 12 + 1;
    final ultimo = DateTime(y, m + 1, 0).day;
    final day = d.day > ultimo ? ultimo : d.day;
    return DateTime(y, m, day);
  }

  static Future<Map<String, dynamic>?> ultimoRecibo(String empleadoId) async {
    final rows = List<Map<String, dynamic>>.from(await db
        .from('recibos')
        .select('*, nominas(periodo_fin, estado, tasa_bcv)')
        .eq('empleado_id', empleadoId));
    final valid = rows.where((r) {
      final n = r['nominas'];
      return n is Map && ['aprobada', 'pagada'].contains(n['estado']);
    }).toList();
    valid.sort((a, b) {
      final fa = a['nominas']['periodo_fin'] as String? ?? '';
      final fb = b['nominas']['periodo_fin'] as String? ?? '';
      return fb.compareTo(fa);
    });
    return valid.isEmpty ? null : valid.first;
  }

  static Future<String> empresa() => Repo.ajuste('empresa_nombre');
  static Future<String> rif() => Repo.ajuste('empresa_rif');
}

class PrestacionesCalculo {
  final double saldoGarantia;
  final double intereses;
  final List<Map<String, dynamic>> meses;
  PrestacionesCalculo(this.saldoGarantia, this.intereses, this.meses);
}

Future<PrestacionesCalculo> calcularInteresesPrestaciones({
  required PrestacionesConfig config,
  required List<PrestacionesMovimiento> movimientos,
  required List<TasaInteresPrestaciones> tasas,
  required DateTime hasta,
}) async {
  final noIntereses = movimientos.where((m) => m.tipo != 'interes').toList()
    ..sort((a, b) => a.fecha.compareTo(b.fecha));
  if (noIntereses.isEmpty) {
    return PrestacionesCalculo(0, 0, []);
  }
  final saldoGarantia = noIntereses
      .where((m) => !m.fecha.isAfter(hasta))
      .fold<double>(0, (s, m) => s + m.monto);
  final porMes = <String, TasaInteresPrestaciones>{
    for (final t in tasas)
      '${t.periodo.year}-${t.periodo.month.toString().padLeft(2, '0')}': t
  };

  var inicio = DateTime(noIntereses.first.fecha.year,
      noIntereses.first.fecha.month, 1);
  var fin = DateTime(hasta.year, hasta.month, 1);
  if (fin.isBefore(inicio)) fin = inicio;

  var base = 0.0;
  var acumulado = 0.0;
  var idx = 0;
  final meses = <Map<String, dynamic>>[];

  while (!inicio.isAfter(fin)) {
    final finMes = DateTime(inicio.year, inicio.month + 1, 0);
    while (idx < noIntereses.length &&
        !noIntereses[idx].fecha.isAfter(finMes)) {
      base += noIntereses[idx].monto;
      idx++;
    }
    final clave =
        '${inicio.year}-${inicio.month.toString().padLeft(2, '0')}';
    final t = porMes[clave];
    final tasaAnual = _tasa(t, config.tipoTasa);
    final interes = base * tasaAnual / 12;
    if (interes != 0) {
      acumulado += interes;
      if (config.capitalizarIntereses) base += interes;
      meses.add({
        'periodo': inicio,
        'base': base,
        'tasa': tasaAnual,
        'interes': interes,
      });
    }
    inicio = DateTime(inicio.year, inicio.month + 1, 1);
  }
  return PrestacionesCalculo(saldoGarantia, acumulado, meses);
}

double _tasa(TasaInteresPrestaciones? t, String tipo) {
  if (t == null) return 0;
  switch (tipo) {
    case 'activa':
      return t.tasaActiva;
    case 'promedio':
      return t.tasaPromedio;
    case 'rendimiento':
      return t.rendimientoFideicomiso;
    default:
      return t.tasaPasiva;
  }
}
