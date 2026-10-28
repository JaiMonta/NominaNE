String? tokenAsistenciaDesde(Uri uri) {
  final direct =
      uri.queryParameters['asistencia'] ?? uri.queryParameters['token'];
  if (direct != null && direct.trim().isNotEmpty) return direct.trim();

  final fragment = uri.fragment;
  if (fragment.isEmpty) return null;

  final parsed = Uri.tryParse(fragment.startsWith('/') ? fragment : '/$fragment');
  if (parsed == null) return null;

  final token =
      parsed.queryParameters['asistencia'] ?? parsed.queryParameters['token'];
  return token != null && token.trim().isNotEmpty ? token.trim() : null;
}
