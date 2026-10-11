double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

class Empleado {
  final String? id;
  String cedula, nombres, apellidos, tipo, jornada, frecuenciaPago;
  String? cargo, departamento, banco, cuenta, email;
  DateTime fechaIngreso;
  DateTime? fechaEgreso;
  double salarioMensualUsd;
  bool activo;

  Empleado({
    this.id,
    this.cedula = '',
    this.nombres = '',
    this.apellidos = '',
    this.cargo,
    this.departamento,
    this.tipo = 'empleado',
    DateTime? fechaIngreso,
    this.fechaEgreso,
    this.salarioMensualUsd = 0,
    this.jornada = 'diurna',
    this.frecuenciaPago = 'quincenal',
    this.banco,
    this.cuenta,
    this.email,
    this.activo = true,
  }) : fechaIngreso = fechaIngreso ?? DateTime.now();

  String get nombreCompleto => '$nombres $apellidos';

  factory Empleado.fromJson(Map<String, dynamic> j) => Empleado(
        id: j['id'],
        cedula: j['cedula'] ?? '',
        nombres: j['nombres'] ?? '',
        apellidos: j['apellidos'] ?? '',
        cargo: j['cargo'],
        departamento: j['departamento'],
        tipo: j['tipo'] ?? 'empleado',
        fechaIngreso: DateTime.parse(j['fecha_ingreso']),
        fechaEgreso:
            j['fecha_egreso'] == null ? null : DateTime.parse(j['fecha_egreso']),
        salarioMensualUsd: _d(j['salario_mensual_usd']),
        jornada: j['jornada'] ?? 'diurna',
        frecuenciaPago: j['frecuencia_pago'] ?? 'quincenal',
        banco: j['banco'],
        cuenta: j['cuenta'],
        email: j['email'],
        activo: j['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'cedula': cedula,
        'nombres': nombres,
        'apellidos': apellidos,
        'cargo': cargo,
        'departamento': departamento,
        'tipo': tipo,
        'fecha_ingreso': fechaIngreso.toIso8601String().substring(0, 10),
        'fecha_egreso': fechaEgreso?.toIso8601String().substring(0, 10),
        'salario_mensual_usd': salarioMensualUsd,
        'jornada': jornada,
        'frecuencia_pago': frecuenciaPago,
        'banco': banco,
        'cuenta': cuenta,
        'email': email,
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
  final String nombre, frecuencia, estado;
  final DateTime inicio, fin;
  final double totalIngresos, totalEgresos, totalNeto, totalAportes;
  final double? tasaBcv;

  Nomina.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        nombre = j['nombre'],
        frecuencia = j['frecuencia'] ?? '',
        estado = j['estado'] ?? 'borrador',
        inicio = DateTime.parse(j['periodo_inicio']),
        fin = DateTime.parse(j['periodo_fin']),
        totalIngresos = _d(j['total_ingresos']),
        totalEgresos = _d(j['total_egresos']),
        totalNeto = _d(j['total_neto']),
        totalAportes = _d(j['total_aportes_patronales']),
        tasaBcv = j['tasa_bcv'] == null ? null : _d(j['tasa_bcv']);
}

class Recibo {
  final String id;
  final String empleadoId;
  final String nombreEmpleado, cedula;
  final double ingresos, egresos, neto, aportes;
  final double salarioMensualUsd, ingresosUsd, egresosUsd, netoUsd;
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
        tasaBcv = j['tasa_bcv'] == null ? null : _d(j['tasa_bcv']);
}
