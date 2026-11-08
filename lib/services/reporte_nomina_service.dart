import '../core/periodo_nomina.dart';
import '../models/models.dart';
import 'repo.dart';

class ReciboReporte {
  final Recibo recibo;
  final List<Map<String, dynamic>> detalle;

  const ReciboReporte({required this.recibo, required this.detalle});
}

class NominaReporte {
  final Nomina nomina;
  final List<ReciboReporte> recibos;

  const NominaReporte({required this.nomina, required this.recibos});
}

class ReporteNomina {
  final String etiqueta;
  final String empresa;
  final String rif;
  final DateTime inicio;
  final DateTime fin;
  final List<NominaReporte> nominas;

  const ReporteNomina({
    required this.etiqueta,
    required this.empresa,
    required this.rif,
    required this.inicio,
    required this.fin,
    required this.nominas,
  });
}

class ReporteNominaService {
  static Future<ReporteNomina> cargar({
    required TipoPeriodoNomina tipo,
    required DateTime referencia,
  }) async {
    final rango = rangoNomina(tipo, referencia);
    final empresa = await Repo.ajuste('empresa_nombre');
    final rif = await Repo.ajuste('empresa_rif');

    final rows = await db
        .from('nominas')
        .select(
            '*, recibos(*, empleados(nombres,apellidos,cedula), recibo_detalle(*))')
        .gte('periodo_fin', fecha(rango.inicio))
        .lte('periodo_fin', fecha(rango.fin))
        .inFilter('estado', ['aprobada', 'pagada'])
        .order('periodo_fin', ascending: true)
        .order('created_at', ascending: true);

    final nominas = <NominaReporte>[];
    for (final rawNomina in rows) {
      final nominaMap = Map<String, dynamic>.from(rawNomina);
      final nomina = Nomina.fromJson(nominaMap);
      final recibos = <ReciboReporte>[];
      final rawRecibos = nominaMap['recibos'];

      if (rawRecibos is List) {
        for (final rawRecibo in rawRecibos) {
          final reciboMap = Map<String, dynamic>.from(rawRecibo as Map);
          final detalle = <Map<String, dynamic>>[];
          final rawDetalle = reciboMap['recibo_detalle'];
          if (rawDetalle is List) {
            for (final rawLinea in rawDetalle) {
              detalle.add(Map<String, dynamic>.from(rawLinea as Map));
            }
          }
          detalle.sort((a, b) {
            final tipo = (b['tipo'] ?? '').toString().compareTo(
                (a['tipo'] ?? '').toString());
            if (tipo != 0) return tipo;
            return (a['concepto_codigo'] ?? '')
                .toString()
                .compareTo((b['concepto_codigo'] ?? '').toString());
          });
          recibos.add(ReciboReporte(
            recibo: Recibo.fromJson(reciboMap),
            detalle: detalle,
          ));
        }
      }

      recibos.sort((a, b) => a.recibo.nombreEmpleado
          .toLowerCase()
          .compareTo(b.recibo.nombreEmpleado.toLowerCase()));
      nominas.add(NominaReporte(nomina: nomina, recibos: recibos));
    }

    return ReporteNomina(
      etiqueta: etiquetaNomina(tipo, rango),
      empresa: empresa,
      rif: rif,
      inicio: rango.inicio,
      fin: rango.fin,
      nominas: nominas,
    );
  }
}
