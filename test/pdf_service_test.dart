import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/models/models.dart';
import 'package:nomina_app/services/pdf_service.dart';

void main() {
  test('pagina recibos en lotes de 4', () {
    final grupos = paginarRecibos(List.generate(5, (i) => i), 4);
    expect(grupos.length, 2);
    expect(grupos[0].length, 4);
    expect(grupos[1].length, 1);
  });

  test('pagina recibos en lotes de 3', () {
    final grupos = paginarRecibos(List.generate(5, (i) => i), 3);
    expect(grupos.length, 2);
    expect(grupos[0].length, 3);
    expect(grupos[1].length, 2);
  });

  test('limita el máximo a 6 recibos por hoja', () {
    final grupos = paginarRecibos(List.generate(7, (i) => i), 9);
    expect(grupos.length, 2);
    expect(grupos[0].length, 6);
    expect(grupos[1].length, 1);
  });

  test('formatos A4, Carta y Oficio', () {
    expect(formatoHoja(HojaNomina.a4).width, closeTo(595.28, 0.1));
    expect(formatoHoja(HojaNomina.carta).width, closeTo(612, 0.1));
    expect(formatoHoja(HojaNomina.oficio).height, closeTo(936, 0.1));
  });

  test('genera PDF de nómina compacto con varios recibos por hoja', () async {
    final nomina = Nomina.fromJson({
      'id': 'n1',
      'nombre': 'Semana 1',
      'frecuencia': 'semanal',
      'estado': 'borrador',
      'modalidad_nomina': 'normal',
      'periodo_inicio': '2026-10-01',
      'periodo_fin': '2026-10-07',
      'total_ingresos': 1000,
      'total_egresos': 100,
      'total_neto': 900,
      'total_aportes_patronales': 50,
      'total_aporte_ivss': 10,
      'total_aporte_rpe': 5,
      'total_aporte_faov': 10,
      'total_aporte_lopcymat': 5,
      'total_aporte_ince': 20,
      'tasa_bcv': 10,
    });

    final items = List.generate(
      5,
      (i) => ReciboPdfData(
        Recibo.fromJson({
          'id': 'r$i',
          'empleado_id': 'e$i',
          'empleados': {
            'nombres': 'Empleado',
            'apellidos': '${i + 1}',
            'cedula': '${100000 + i}',
          },
          'total_ingresos': 1000,
          'total_egresos': 100,
          'neto': 900,
          'aportes_patronales': 50,
          'salario_mensual_usd': 100,
          'total_ingresos_usd': 10,
          'total_egresos_usd': 1,
          'neto_usd': 9,
          'aporte_ivss_patronal': 10,
          'aporte_rpe_patronal': 5,
          'aporte_faov_patronal': 10,
          'aporte_lopcymat_patronal': 5,
          'aporte_ince_patronal': 20,
          'tasa_bcv': 10,
        }),
        [
          {
            'concepto_nombre': 'Sueldo',
            'cantidad': 1,
            'tipo': 'ingreso',
            'monto': 1000,
            'monto_usd': 100,
            'es_salarial': true,
            'base_legal': 'LOT',
          },
          {
            'concepto_nombre': 'IVSS',
            'cantidad': 1,
            'tipo': 'egreso',
            'monto': 10,
            'monto_usd': 1,
            'es_salarial': false,
            'base_legal': 'LSS',
          },
        ],
      ),
    );

    final conCuatro = await buildNominaPdf(
      nomina: nomina,
      items: items,
      empresa: 'Empresa',
      rif: 'J-1',
      hoja: HojaNomina.a4,
      recibosPorPagina: 4,
    );
    expect(conCuatro.length, greaterThan(0));

    final conTres = await buildNominaPdf(
      nomina: nomina,
      items: items,
      empresa: 'Empresa',
      rif: 'J-1',
      hoja: HojaNomina.carta,
      recibosPorPagina: 3,
    );
    expect(conTres.length, greaterThan(0));

    final conSeis = await buildNominaPdf(
      nomina: nomina,
      items: items,
      empresa: 'Empresa',
      rif: 'J-1',
      hoja: HojaNomina.oficio,
      recibosPorPagina: 6,
    );
    expect(conSeis.length, greaterThan(0));
  });
}
