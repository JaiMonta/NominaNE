import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/core/payroll_engine.dart';
import 'package:nomina_app/models/models.dart';

void main() {
  test('r2 redondea a 2 decimales', () {
    expect(r2(1.236), 1.24);
    expect(r2(10.0), 10.0);
  });

  test('días de vacaciones aumentan por año con tope', () {
    final e = PayrollEngine({
      'vacaciones_dias_base': 15,
      'vacaciones_dia_adicional': 1,
      'vacaciones_dias_max': 30,
    });
    expect(e.diasVacaciones(0), 0);
    expect(e.diasVacaciones(1), 15);
    expect(e.diasVacaciones(20), 30);
  });

  test('Empleado usa el departamento relacionado y cae al texto legacy', () {
    final conJoin = Empleado.fromJson({
      'cedula': '1',
      'nombres': 'Ana',
      'apellidos': 'Pérez',
      'fecha_ingreso': '2026-01-01',
      'departamento': 'Texto viejo',
      'departamento_id': 'd1',
      'departamentos': {'nombre': 'Producción'},
    });
    expect(conJoin.departamento, 'Producción');
    expect(conJoin.departamentoId, 'd1');

    final sinJoin = Empleado.fromJson({
      'cedula': '2',
      'nombres': 'Luis',
      'apellidos': 'Gómez',
      'fecha_ingreso': '2026-01-01',
      'departamento': 'Ventas',
    });
    expect(sinJoin.departamento, 'Ventas');
    expect(sinJoin.departamentoId, isNull);
  });

  test('Empleado y Nomina leen modalidad_nomina', () {
    final e = Empleado.fromJson({
      'cedula': '3',
      'nombres': 'Ana',
      'apellidos': 'Pérez',
      'fecha_ingreso': '2026-01-01',
      'modalidad_nomina': 'contratado',
    });
    expect(e.modalidad, 'contratado');

    final n = Nomina.fromJson({
      'id': 'n1',
      'nombre': 'Contratados',
      'frecuencia': 'mensual',
      'estado': 'borrador',
      'periodo_inicio': '2026-10-01',
      'periodo_fin': '2026-10-31',
      'modalidad_nomina': 'contratado',
    });
    expect(n.modalidad, 'contratado');
  });
}
