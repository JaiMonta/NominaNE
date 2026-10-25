double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

String? _departamentoJson(Map<String, dynamic> j) {
  final d = j['departamentos'];
  if (d is Map) return d['nombre'] as String?;
  if (d is List && d.isNotEmpty) {
    final first = d.first;
    if (first is Map) return first['nombre'] as String?;
  }
  return j['departamento'] as String?;
}

class Departamento {
  final String? id;
  String nombre;
  bool activo;
  int orden;

  Departamento({
    this.id,
    this.nombre = '',
    this.activo = true,
    this.orden = 999,
  });

  factory Departamento.fromJson(Map<String, dynamic> j) => Departamento(
        id: j['id'],
        nombre: j['nombre'] ?? '',
        activo: j['activo'] ?? true,
        orden: (j['orden'] as num?)?.toInt() ?? 999,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'activo': activo,
        'orden': orden,
      };
}

class Empleado {
  final String? id;
  String cedula, nombres, apellidos, tipo, jornada, frecuenciaPago, modalidad;
  String? cargo, departamento, departamentoId, banco, cuenta, email, telefono;
  DateTime fechaIngreso;
  DateTime? fechaEgreso, fechaNacimiento;
  double salarioMensualUsd;
  bool activo;

  Empleado({
    this.id,
    this.cedula = '',
    this.nombres = '',
    this.apellidos = '',
    this.cargo,
    this.departamento,
    this.departamentoId,
    this.tipo = 'empleado',
    DateTime? fechaIngreso,
    this.fechaEgreso,
    this.fechaNacimiento,
    this.salarioMensualUsd = 0,
    this.jornada = 'diurna',
    this.frecuenciaPago = 'quincenal',
    this.modalidad = 'normal',
    this.banco,
    this.cuenta,
    this.email,
    this.telefono,
    this.activo = true,
  }) : fechaIngreso = fechaIngreso ?? DateTime.now();

  String get nombreCompleto => '$nombres $apellidos';

  factory Empleado.fromJson(Map<String, dynamic> j) => Empleado(
        id: j['id'],
        cedula: j['cedula'] ?? '',
        nombres: j['nombres'] ?? '',
        apellidos: j['apellidos'] ?? '',
        cargo: j['cargo'],
        departamento: _departamentoJson(j),
        departamentoId: j['departamento_id'],
        tipo: j['tipo'] ?? 'empleado',
        fechaIngreso: DateTime.parse(j['fecha_ingreso']),
        fechaEgreso:
            j['fecha_egreso'] == null ? null : DateTime.parse(j['fecha_egreso']),
        fechaNacimiento: j['fecha_nacimiento'] == null
            ? null
            : DateTime.parse(j['fecha_nacimiento']),
        salarioMensualUsd: _d(j['salario_mensual_usd']),
        jornada: j['jornada'] ?? 'diurna',
        frecuenciaPago: j['frecuencia_pago'] ?? 'quincenal',
        modalidad: j['modalidad_nomina'] ?? 'normal',
        banco: j['banco'],
        cuenta: j['cuenta'],
        email: j['email'],
        telefono: j['telefono'],
        activo: j['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'cedula': cedula,
        'nombres': nombres,
        'apellidos': apellidos,
        'cargo': cargo,
        'departamento': departamento,
        'departamento_id': departamentoId,
        'tipo': tipo,
        'fecha_ingreso': fechaIngreso.toIso8601String().substring(0, 10),
        'fecha_egreso': fechaEgreso?.toIso8601String().substring(0, 10),
        'fecha_nacimiento':
            fechaNacimiento?.toIso8601String().substring(0, 10),
        'salario_mensual_usd': salarioMensualUsd,
        'jornada': jornada,
        'frecuencia_pago': frecuenciaPago,
        'modalidad_nomina': modalidad,
        'banco': banco,
        'cuenta': cuenta,
        'email': email,
        'telefono': telefono,
        'activo': activo,
      };
}

class Concepto {
  final String? id;
  String codigo, nombre, tipo, calculo;
  String? baseLegal;
  bool esSalarial, automatico, activo;
  double valor;

  Concepto({
    this.id,
    this.codigo = '',
    this.nombre = '',
    this.tipo = 'ingreso',
    this.baseLegal,
    this.esSalarial = true,
    this.calculo = 'manual',
    this.valor = 0,
    this.automatico = false,
    this.activo = true,
  });

  factory Concepto.fromJson(Map<String, dynamic> j) => Concepto(
        id: j['id'],
        codigo: j['codigo'],
        nombre: j['nombre'],
        tipo: j['tipo'],
        baseLegal: j['base_legal'],
        esSalarial: j['es_salarial'] ?? true,
        calculo: j['calculo'] ?? 'manual',
        valor: _d(j['valor']),
        automatico: j['automatico'] ?? false,
        activo: j['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nombre': nombre,
        'tipo': tipo,
        'base_legal': baseLegal,
        'es_salarial': esSalarial,
        'calculo': calculo,
        'valor': valor,
        'automatico': automatico,
        'activo': activo,
      };
}

class Nomina {
  final String id;
  final String nombre, frecuencia, estado, modalidad;
  final DateTime inicio, fin;
  final double totalIngresos, totalEgresos, totalNeto, totalAportes;
  final double totalAporteIvss, totalAporteRpe, totalAporteFaov, totalAporteLopcymat;
  final double? tasaBcv;

  Nomina.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        nombre = j['nombre'],
        frecuencia = j['frecuencia'] ?? '',
        estado = j['estado'] ?? 'borrador',
        modalidad = j['modalidad_nomina'] ?? 'normal',
        inicio = DateTime.parse(j['periodo_inicio']),
        fin = DateTime.parse(j['periodo_fin']),
        totalIngresos = _d(j['total_ingresos']),
        totalEgresos = _d(j['total_egresos']),
        totalNeto = _d(j['total_neto']),
        totalAportes = _d(j['total_aportes_patronales']),
        totalAporteIvss = _d(j['total_aporte_ivss']),
        totalAporteRpe = _d(j['total_aporte_rpe']),
        totalAporteFaov = _d(j['total_aporte_faov']),
        totalAporteLopcymat = _d(j['total_aporte_lopcymat']),
        tasaBcv = j['tasa_bcv'] == null ? null : _d(j['tasa_bcv']);
}

class Recibo {
  final String id;
  final String empleadoId;
  final String nombreEmpleado, cedula;
  final double ingresos, egresos, neto, aportes;
  final double salarioMensualUsd, ingresosUsd, egresosUsd, netoUsd;
  final double aporteIvss, aporteRpe, aporteFaov, aporteLopcymat;
  final double? tasaBcv;

  Recibo.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        empleadoId = j['empleado_id'],
        nombreEmpleado = j['empleados'] == null
            ? ''
            : '${j['empleados']['nombres']} ${j['empleados']['apellidos']}',
        cedula = j['empleados']?['cedula'] ?? '',
        ingresos = _d(j['total_ingresos']),
        egresos = _d(j['total_egresos']),
        neto = _d(j['neto']),
        aportes = _d(j['aportes_patronales']),
        salarioMensualUsd = _d(j['salario_mensual_usd']),
        ingresosUsd = _d(j['total_ingresos_usd']),
        egresosUsd = _d(j['total_egresos_usd']),
        netoUsd = _d(j['neto_usd']),
        aporteIvss = _d(j['aporte_ivss_patronal']),
        aporteRpe = _d(j['aporte_rpe_patronal']),
        aporteFaov = _d(j['aporte_faov_patronal']),
        aporteLopcymat = _d(j['aporte_lopcymat_patronal']),
        tasaBcv = j['tasa_bcv'] == null ? null : _d(j['tasa_bcv']);
}
