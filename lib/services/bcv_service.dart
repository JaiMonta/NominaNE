import 'dart:convert';
import 'package:http/http.dart' as http;

class BcvTasa {
  final double tasa;
  final DateTime fecha;
  final String fuente;
  const BcvTasa(this.tasa, this.fecha, this.fuente);
}

class BcvService {
  static String _dia(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Tasa oficial BCV (Bs/USD) para [dia]. En fines de semana o feriados
  /// devuelve la última tasa publicada. Devuelve null si no se pudo obtener.
  static Future<BcvTasa?> delDia(DateTime dia) async {
    final historica = await _porFecha(dia);
    if (historica != null) return historica;

    final ultima = await _ultima();
    if (ultima == null) return _dolarApi();
    // Si la fecha pedida es posterior a la última publicada, sirve la última.
    return dia.isAfter(ultima.fecha) ? ultima : null;
  }

  static Future<BcvTasa?> _porFecha(DateTime dia) async {
    return _leer('https://bcv.today/api/v1/history/${_dia(dia)}.json');
  }

  static Future<BcvTasa?> _ultima() async {
    return _leer('https://bcv.today/api/v1/rate.json');
  }

  static Future<BcvTasa?> _leer(String url) async {
    try {
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final v = j['USD'];
      if (v is! num || v <= 0) return null;
      final efectiva = (j['effective_date'] ?? j['date'])?.toString();
      final f = efectiva == null ? null : DateTime.tryParse(efectiva);
      if (f == null) return null;
      return BcvTasa(v.toDouble(), f, 'BCV');
    } catch (_) {
      return null;
    }
  }

  static Future<BcvTasa?> _dolarApi() async {
    try {
      final r = await http
          .get(Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final v = j['promedio'];
      if (v is! num || v <= 0) return null;
      final f = DateTime.tryParse((j['fechaActualizacion'] ?? '').toString());
      return BcvTasa(v.toDouble(), f ?? DateTime.now(), 'BCV (DolarApi)');
    } catch (_) {
      return null;
    }
  }
}
