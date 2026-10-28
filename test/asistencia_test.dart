import 'package:flutter_test/flutter_test.dart';
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
    });
    expect(a.horas, closeTo(9.5, 0.001));
    expect(a.pendiente, isFalse);

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
}
