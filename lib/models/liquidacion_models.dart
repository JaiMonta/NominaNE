double _n(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
String _fecha(DateTime d) => d.toIso8601String().substring(0, 10);

class MotivosEgreso {
  static const renuncia = 'renuncia';
  static const despidoJustificado = 'despido_justificado';
  static const despidoInjustificado = 'despido_injustificado';
  static const mutuoAcuerdo = 'mutuo_acuerdo';
  static const finContrato = 'fin_contrato';
  static const jubilacion = 'jubilacion';
  static const fallecimiento = 'fallecimiento';

  static const todos = [
    renuncia,
    despidoJustificado,
    despidoInjustificado,
    mutuoAcuerdo,
    finContrato,
    jubilacion,
    fallecimiento,
  ];

  static String label(String motivo) {
    switch (motivo) {
      case renuncia:
        return 'Renuncia';
      case despidoJustificado:
        return 'Despido justificado';
      case despidoInjustificado:
        return 'Despido injustificado';
      case mutuoAcuerdo:
        return 'Mutuo acuerdo';
      case finContrato:
        return 'Fin de contrato';
      case jubilacion:
        return 'Jubilación';
      case fallecimiento:
        return 'Fallecimiento';
      default:
        return motivo;
    }
  }

  static bool indemnizacionPorDefecto(String motivo) =>
      motivo == despidoInjustificado || motivo == fallecimiento;
}

class PrestacionesConfig {
  final String? id;
  final String empleadoId;
  DateTime vigenteDesde;
  String modalidad;
  String tipoTasa;
  bool capitalizarIntereses;
  String? nota;

  PrestacionesConfig({
    this.id,
    required this.empleadoId,
    required this.vigenteDesde,
    this.modalidad = 'contabilidad',
    this.tipoTasa = 'pasiva',
    this.capitalizarIntereses = false,
    this.nota,
  });

  factory PrestacionesConfig.fromJson(Map<String, dynamic> j) =>
      PrestacionesConfig(
        id: j['id'],
        empleadoId: j['empleado_id'],
        vigenteDesde: DateTime.parse(j['vigente_desde']),
        modalidad: j['modalidad'] ?? 'contabilidad',
        tipoTasa: j['tipo_tasa'] ?? 'pasiva',
        capitalizarIntereses: j['capitalizar_intereses'] ?? false,
        nota: j['nota'],
      );

  Map<String, dynamic> toJson() => {
        'empleado_id': empleadoId,
        'vigente_desde': _fecha(vigenteDesde),
        'modalidad': modalidad,
        'tipo_tasa': tipoTasa,
        'capitalizar_intereses': capitalizarIntereses,
        'nota': nota,
      };

  String get modalidadLabel {
    switch (modalidad) {
      case 'fideicomiso':
        return 'Fideicomiso';
      case 'fondo':
        return 'Fondo Nacional';
      case 'no_depositada':
        return 'No depositada';
      default:
        return 'Contabilidad';
    }
  }

  String get tipoTasaLabel {
    switch (tipoTasa) {
      case 'promedio':
        return 'Promedio activa/pasiva';
      case 'activa':
        return 'Activa';
      case 'rendimiento':
        return 'Rendimiento fideicomiso';
      default:
        return 'Pasiva';
    }
  }
}

class PrestacionesMovimiento {
  final String? id;
  final String empleadoId;
  DateTime fecha;
  DateTime? periodo;
  String tipo;
  double dias;
  double salarioIntegral;
  double monto;
  double? tasaInteres;
  String? modalidad;
  String? nota;
  String? liquidacionId;

  PrestacionesMovimiento({
    this.id,
    required this.empleadoId,
    required this.fecha,
    this.periodo,
    required this.tipo,
    this.dias = 0,
    this.salarioIntegral = 0,
    this.monto = 0,
    this.tasaInteres,
    this.modalidad,
    this.nota,
    this.liquidacionId,
  });

  factory PrestacionesMovimiento.fromJson(Map<String, dynamic> j) =>
      PrestacionesMovimiento(
        id: j['id'],
        empleadoId: j['empleado_id'],
        fecha: DateTime.parse(j['fecha']),
        periodo: j['periodo'] == null ? null : DateTime.parse(j['periodo']),
        tipo: j['tipo'],
        dias: _n(j['dias']),
        salarioIntegral: _n(j['salario_integral']),
        monto: _n(j['monto']),
        tasaInteres: j['tasa_interes'] == null ? null : _n(j['tasa_interes']),
        modalidad: j['modalidad'],
        nota: j['nota'],
        liquidacionId: j['liquidacion_id'],
      );

  Map<String, dynamic> toJson() => {
        'empleado_id': empleadoId,
        'fecha': _fecha(fecha),
        'periodo': periodo == null ? null : _fecha(periodo!),
        'tipo': tipo,
        'dias': dias,
        'salario_integral': salarioIntegral,
        'monto': monto,
        'tasa_interes': tasaInteres,
        'modalidad': modalidad,
        'nota': nota,
        'liquidacion_id': liquidacionId,
      };

  String get tipoLabel {
    switch (tipo) {
      case 'saldo_inicial':
        return 'Saldo inicial';
      case 'garantia_trimestral':
        return 'Garantía trimestral';
      case 'dias_adicionales':
        return 'Días adicionales';
      case 'interes':
        return 'Intereses';
      case 'anticipo':
        return 'Anticipo';
      case 'pago':
        return 'Pago';
      default:
        return 'Ajuste';
    }
  }
}

class TasaInteresPrestaciones {
  DateTime periodo;
  double tasaActiva;
  double tasaPasiva;
  double tasaPromedio;
  double rendimientoFideicomiso;
  String fuente;

  TasaInteresPrestaciones({
    required this.periodo,
    this.tasaActiva = 0,
    this.tasaPasiva = 0,
    this.tasaPromedio = 0,
    this.rendimientoFideicomiso = 0,
    this.fuente = 'BCV',
  });

  factory TasaInteresPrestaciones.fromJson(Map<String, dynamic> j) =>
      TasaInteresPrestaciones(
        periodo: DateTime.parse(j['periodo']),
        tasaActiva: _n(j['tasa_activa']),
        tasaPasiva: _n(j['tasa_pasiva']),
        tasaPromedio: _n(j['tasa_promedio']),
        rendimientoFideicomiso: _n(j['rendimiento_fideicomiso']),
        fuente: j['fuente'] ?? 'BCV',
      );

  Map<String, dynamic> toJson() => {
        'periodo': _fecha(periodo),
        'tasa_activa': tasaActiva,
        'tasa_pasiva': tasaPasiva,
        'tasa_promedio': tasaPromedio,
        'rendimiento_fideicomiso': rendimientoFideicomiso,
        'fuente': fuente,
      };
}

class VacacionesPeriodo {
  final String? id;
  final String empleadoId;
  DateTime periodoInicio;
  DateTime periodoFin;
  double diasVacaciones;
  double diasBono;
  double diasDisfrutados;
  double diasBonoPagados;
  double salarioNormal;
  String? nota;

  VacacionesPeriodo({
    this.id,
    required this.empleadoId,
    required this.periodoInicio,
    required this.periodoFin,
    this.diasVacaciones = 0,
    this.diasBono = 0,
    this.diasDisfrutados = 0,
    this.diasBonoPagados = 0,
    this.salarioNormal = 0,
    this.nota,
  });

  factory VacacionesPeriodo.fromJson(Map<String, dynamic> j) =>
      VacacionesPeriodo(
        id: j['id'],
        empleadoId: j['empleado_id'],
        periodoInicio: DateTime.parse(j['periodo_inicio']),
        periodoFin: DateTime.parse(j['periodo_fin']),
        diasVacaciones: _n(j['dias_vacaciones']),
        diasBono: _n(j['dias_bono']),
        diasDisfrutados: _n(j['dias_disfrutados']),
        diasBonoPagados: _n(j['dias_bono_pagados']),
        salarioNormal: _n(j['salario_normal']),
        nota: j['nota'],
      );

  Map<String, dynamic> toJson() => {
        'empleado_id': empleadoId,
        'periodo_inicio': _fecha(periodoInicio),
        'periodo_fin': _fecha(periodoFin),
        'dias_vacaciones': diasVacaciones,
        'dias_bono': diasBono,
        'dias_disfrutados': diasDisfrutados,
        'dias_bono_pagados': diasBonoPagados,
        'salario_normal': salarioNormal,
        'nota': nota,
      };

  double get pendienteVacaciones =>
      (diasVacaciones - diasDisfrutados).clamp(0, double.infinity);
  double get pendienteBono =>
      (diasBono - diasBonoPagados).clamp(0, double.infinity);
}

class Liquidacion {
  final String? id;
  final String empleadoId;
  final DateTime fechaIngreso;
  final DateTime fechaEgreso;
  final String motivo;
  final DateTime fechaCalculo;
  final double? tasaBcv;
  final double salarioNormalUsd;
  final double salarioNormalBs;
  final double salarioIntegralBs;
  final int anios;
  final int meses;
  final int dias;
  final double garantiaBs;
  final double interesesBs;
  final double retroactivoBs;
  final double prestacionesBs;
  final double vacacionesBs;
  final double bonoVacBs;
  final double utilidadesBs;
  final double indemnizacionBs;
  final double salarioPendienteBs;
  final double otrosIngresosBs;
  final double deduccionesBs;
  final double netoBs;
  final double totalUsd;
  final String estado;
  final String? nota;
  final DateTime? createdAt;

  Liquidacion({
    this.id,
    required this.empleadoId,
    required this.fechaIngreso,
    required this.fechaEgreso,
    required this.motivo,
    required this.fechaCalculo,
    this.tasaBcv,
    this.salarioNormalUsd = 0,
    this.salarioNormalBs = 0,
    this.salarioIntegralBs = 0,
    this.anios = 0,
    this.meses = 0,
    this.dias = 0,
    this.garantiaBs = 0,
    this.interesesBs = 0,
    this.retroactivoBs = 0,
    this.prestacionesBs = 0,
    this.vacacionesBs = 0,
    this.bonoVacBs = 0,
    this.utilidadesBs = 0,
    this.indemnizacionBs = 0,
    this.salarioPendienteBs = 0,
    this.otrosIngresosBs = 0,
    this.deduccionesBs = 0,
    this.netoBs = 0,
    this.totalUsd = 0,
    this.estado = 'borrador',
    this.nota,
    this.createdAt,
  });

  factory Liquidacion.fromJson(Map<String, dynamic> j) => Liquidacion(
        id: j['id'],
        empleadoId: j['empleado_id'],
        fechaIngreso: DateTime.parse(j['fecha_ingreso']),
        fechaEgreso: DateTime.parse(j['fecha_egreso']),
        motivo: j['motivo'],
        fechaCalculo: DateTime.parse(j['fecha_calculo']),
        tasaBcv: j['tasa_bcv'] == null ? null : _n(j['tasa_bcv']),
        salarioNormalUsd: _n(j['salario_normal_usd']),
        salarioNormalBs: _n(j['salario_normal_bs']),
        salarioIntegralBs: _n(j['salario_integral_bs']),
        anios: _i(j['anios']),
        meses: _i(j['meses']),
        dias: _i(j['dias']),
        garantiaBs: _n(j['garantia_bs']),
        interesesBs: _n(j['intereses_bs']),
        retroactivoBs: _n(j['retroactivo_bs']),
        prestacionesBs: _n(j['prestaciones_bs']),
        vacacionesBs: _n(j['vacaciones_bs']),
        bonoVacBs: _n(j['bono_vac_bs']),
        utilidadesBs: _n(j['utilidades_bs']),
        indemnizacionBs: _n(j['indemnizacion_bs']),
        salarioPendienteBs: _n(j['salario_pendiente_bs']),
        otrosIngresosBs: _n(j['otros_ingresos_bs']),
        deduccionesBs: _n(j['deducciones_bs']),
        netoBs: _n(j['neto_bs']),
        totalUsd: _n(j['total_usd']),
        estado: j['estado'] ?? 'borrador',
        nota: j['nota'],
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'empleado_id': empleadoId,
        'fecha_ingreso': _fecha(fechaIngreso),
        'fecha_egreso': _fecha(fechaEgreso),
        'motivo': motivo,
        'fecha_calculo': _fecha(fechaCalculo),
        'tasa_bcv': tasaBcv,
        'salario_normal_usd': salarioNormalUsd,
        'salario_normal_bs': salarioNormalBs,
        'salario_integral_bs': salarioIntegralBs,
        'anios': anios,
        'meses': meses,
        'dias': dias,
        'garantia_bs': garantiaBs,
        'intereses_bs': interesesBs,
        'retroactivo_bs': retroactivoBs,
        'prestaciones_bs': prestacionesBs,
        'vacaciones_bs': vacacionesBs,
        'bono_vac_bs': bonoVacBs,
        'utilidades_bs': utilidadesBs,
        'indemnizacion_bs': indemnizacionBs,
        'salario_pendiente_bs': salarioPendienteBs,
        'otros_ingresos_bs': otrosIngresosBs,
        'deducciones_bs': deduccionesBs,
        'neto_bs': netoBs,
        'total_usd': totalUsd,
        'estado': estado,
        'nota': nota,
      };

  String get motivoLabel => MotivosEgreso.label(motivo);
}

class LiquidacionDetalle {
  final String? id;
  final String? liquidacionId;
  final String codigo;
  final String nombre;
  final String tipo;
  final double dias;
  final double base;
  final double monto;
  final String? baseLegal;
  final int orden;

  LiquidacionDetalle({
    this.id,
    this.liquidacionId,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    this.dias = 0,
    this.base = 0,
    required this.monto,
    this.baseLegal,
    this.orden = 0,
  });

  factory LiquidacionDetalle.fromJson(Map<String, dynamic> j) =>
      LiquidacionDetalle(
        id: j['id'],
        liquidacionId: j['liquidacion_id'],
        codigo: j['codigo'],
        nombre: j['nombre'],
        tipo: j['tipo'],
        dias: _n(j['dias']),
        base: _n(j['base']),
        monto: _n(j['monto']),
        baseLegal: j['base_legal'],
        orden: _i(j['orden']),
      );

  Map<String, dynamic> toJson() => {
        'liquidacion_id': liquidacionId,
        'codigo': codigo,
        'nombre': nombre,
        'tipo': tipo,
        'dias': dias,
        'base': base,
        'monto': monto,
        'base_legal': baseLegal,
        'orden': orden,
      };
}
