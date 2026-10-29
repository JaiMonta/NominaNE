import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/core/asistencia_horarios.dart';
import 'package:nomina_app/core/asistencia_periodo.dart';
import 'package:nomina_app/core/asistencia_url.dart';
import 'package:nomina_app/models/models.dart';

void main() {
  test('token de asistencia desde el query string', () {
    expect(
      tokenAsistenciaDesde(
          Uri.parse('https://nomina-ne.web.app/?asistencia=abc123')),
      'abc123',
    );
  });

  test('token de asistencia desde el fragmento hash', () {
    expect(
      tokenAsistenciaDesde(
          Uri.parse('https://nomina-ne.web.app/#/asistencia?asistencia=xyz')),
      'xyz',
    );
  });

  test('sin token de asistencia devuelve null', () {
    expect(tokenAsistenciaDesde(Uri.parse('https://nomina-ne.web.app/')),
        isNull);
  });

  test('AsistenciaDia calcula horas y estado pendiente', () {
    final a = AsistenciaDia.fromJson({
      'id': 'a1',
      'empleado_id': 'e1',
      'fecha': '2026-10-28',
      'entrada': '2026-10-28T11:00:00+00:00',
      'salida': '2026-10-28T20:30:00+00:00',
      'jornada': 'nocturna',
    });
    expect(a.horas, closeTo(9.5, 0.001));
    expect(a.pendiente, isFalse);
    expect(a.jornada, 'nocturna');

    final b = AsistenciaDia.fromJson({
      'id': 'a2',
      'empleado_id': 'e1',
      'fecha': '2026-10-29',
      'entrada': '2026-10-29T11:00:00+00:00',
      'salida': null,
    });
    expect(b.pendiente, isTrue);
    expect(b.horas, 0);
  });

  test('QrAsistencia lee token y fecha', () {
    final qr = QrAsistencia.fromJson({
      'token': 'abc',
      'fecha': '2026-10-28',
    });
    expect(qr.token, 'abc');
    expect(qr.fecha.year, 2026);
    expect(qr.fecha.month, 10);
    expect(qr.fecha.day, 28);
  });

  test('rango semanal va de lunes a domingo', () {
    final r = rangoAsistencia(
        TipoPeriodoAsistencia.semanal, DateTime(2026, 10, 28));
    expect(r.inicio, DateTime(2026, 10, 26));
    expect(r.fin, DateTime(2026, 11, 1));
  });

  test('rango quincenal cubre 1-15 y 16-fin de mes', () {
    final primera = rangoAsistencia(
        TipoPeriodoAsistencia.quincenal, DateTime(2026, 10, 10));
    expect(primera.inicio, DateTime(2026, 10, 1));
    expect(primera.fin, DateTime(2026, 10, 15));

    final segunda = rangoAsistencia(
        TipoPeriodoAsistencia.quincenal, DateTime(2026, 10, 20));
    expect(segunda.inicio, DateTime(2026, 10, 16));
    expect(segunda.fin, DateTime(2026, 10, 31));

    final febrero = rangoAsistencia(
        TipoPeriodoAsistencia.quincenal, DateTime(2026, 2, 20));
    expect(febrero.inicio, DateTime(2026, 2, 16));
    expect(febrero.fin, DateTime(2026, 2, 28));
  });

  test('rango mensual respeta meses y años bisiestos', () {
    final octubre = rangoAsistencia(
        TipoPeriodoAsistencia.mensual, DateTime(2026, 10, 28));
    expect(octubre.inicio, DateTime(2026, 10, 1));
    expect(octubre.fin, DateTime(2026, 10, 31));

    final febrero = rangoAsistencia(
        TipoPeriodoAsistencia.mensual, DateTime(2028, 2, 10));
    expect(febrero.inicio, DateTime(2028, 2, 1));
    expect(febrero.fin, DateTime(2028, 2, 29));
  });

  test('horarios desde ajustes usan defaults y configuración', () {
    final h = HorariosAsistencia.fromAjustes([
      {'clave': 'asistencia_diurna_entrada', 'valor': '08:00'},
      {'clave': 'asistencia_diurna_salida', 'valor': '17:00'},
      {'clave': 'asistencia_tolerancia_min', 'valor': '10'},
    ]);

    expect(h.para('diurna')!.entradaMin, 8 * 60);
    expect(h.para('diurna')!.salidaMin, 17 * 60);
    expect(h.toleranciaMin, 10);
    expect(h.para('nocturna')!.entradaMin, 22 * 60);
    expect(h.para('nocturna')!.salidaMin, 6 * 60);
    expect(h.para('mixta')!.entradaMin, 10 * 60);
    expect(h.para('mixta')!.salidaMin, 19 * 60);
  });

  test('retardo diurno respeta la tolerancia de 5 minutos', () {
    final h = HorariosAsistencia.fromAjustes([]);
    final horario = h.para('diurna');
    final fecha = DateTime(2026, 10, 28);

    final enTolerancia = calcularRetardo(
      fecha: fecha,
      entrada: DateTime(2026, 10, 28, 7, 5),
      horario: horario,
      toleranciaMin: h.toleranciaMin,
    );
    expect(enTolerancia.retardos, 0);

    final tarde = calcularRetardo(
      fecha: fecha,
      entrada: DateTime(2026, 10, 28, 7, 6),
      horario: horario,
      toleranciaMin: h.toleranciaMin,
    );
    expect(tarde.retardos, 1);
    expect(tarde.minutos, 6);

    final temprano = calcularRetardo(
      fecha: fecha,
      entrada: DateTime(2026, 10, 28, 6, 55),
      horario: horario,
      toleranciaMin: h.toleranciaMin,
    );
    expect(temprano.retardos, 0);
  });

  test('retardo nocturno se mide desde el día de inicio del turno', () {
    final h = HorariosAsistencia.fromAjustes([]);
    final r = calcularRetardo(
      fecha: DateTime(2026, 10, 28),
      entrada: DateTime(2026, 10, 29, 2, 0),
      horario: h.para('nocturna'),
      toleranciaMin: h.toleranciaMin,
    );
    expect(r.retardos, 1);
    expect(r.minutos, 240);
  });

  test('retardo mixto y sin entrada', () {
    final h = HorariosAsistencia.fromAjustes([]);
    final r = calcularRetardo(
      fecha: DateTime(2026, 10, 28),
      entrada: DateTime(2026, 10, 28, 10, 20),
      horario: h.para('mixta'),
      toleranciaMin: h.toleranciaMin,
    );
    expect(r.retardos, 1);
    expect(r.minutos, 20);

    final sinEntrada = calcularRetardo(
      fecha: DateTime(2026, 10, 28),
      entrada: null,
      horario: h.para('mixta'),
      toleranciaMin: h.toleranciaMin,
    );
    expect(sinEntrada.retardos, 0);
    expect(sinEntrada.minutos, 0);
  });
}
