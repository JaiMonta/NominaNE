import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class AsistenciaService {
  static SupabaseClient get _db => Supabase.instance.client;

  static String fechaStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<QrAsistencia> crearQr({bool reemplazar = false}) async {
    final raw = await _db.rpc('crear_qr_asistencia',
        params: {'p_reemplazar': reemplazar});
    return QrAsistencia.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static Future<bool> validarQr(String token) async {
    final raw = await _db
        .rpc('validar_qr_asistencia', params: {'p_token': token});
    return raw == true;
  }

  static Future<Map<String, dynamic>> registrar({
    required String token,
    required String cedula,
    required String pin,
    required String tipo,
  }) async {
    final raw = await _db.rpc('registrar_asistencia', params: {
      'p_token': token,
      'p_cedula': cedula,
      'p_pin': pin,
      'p_tipo': tipo,
    });
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'ok': false, 'error': 'Respuesta inválida del servidor'};
  }

  static Future<List<AsistenciaDia>> asistenciasDelDia(DateTime fecha) async {
    final rows = await _db
        .from('asistencias')
        .select()
        .eq('fecha', fechaStr(fecha))
        .order('entrada');
    return rows
        .map<AsistenciaDia>(
            (j) => AsistenciaDia.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  static Future<List<AsistenciaDia>> asistenciasEntre(
      DateTime inicio, DateTime fin) async {
    final rows = await _db
        .from('asistencias')
        .select()
        .gte('fecha', fechaStr(inicio))
        .lte('fecha', fechaStr(fin))
        .order('fecha');
    return rows
        .map<AsistenciaDia>(
            (j) => AsistenciaDia.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  static Future<Set<String>> pinesAsignados() async {
    final rows = await _db.from('asistencia_pines').select('empleado_id');
    return rows
        .map<String>((j) => j['empleado_id'] as String)
        .toSet();
  }

  static Future<void> asignarPin(String empleadoId, String pin) => _db.rpc(
        'asignar_pin_asistencia',
        params: {'p_empleado_id': empleadoId, 'p_pin': pin},
      );

  static Future<void> registrarManual({
    required String empleadoId,
    required DateTime fecha,
    required String tipo,
    required DateTime hora,
    String? nota,
  }) =>
      _db.rpc('registrar_asistencia_manual', params: {
        'p_empleado_id': empleadoId,
        'p_fecha': fechaStr(fecha),
        'p_tipo': tipo,
        'p_hora': hora.toUtc().toIso8601String(),
        'p_nota': nota,
      });

  static Future<void> corregir({
    required String id,
    DateTime? entrada,
    DateTime? salida,
    String? nota,
  }) =>
      _db.rpc('corregir_asistencia', params: {
        'p_id': id,
        'p_entrada': entrada?.toUtc().toIso8601String(),
        'p_salida': salida?.toUtc().toIso8601String(),
        'p_nota': nota,
      });
}
