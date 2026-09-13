import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de una sugerencia de Google Places Autocomplete.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
}

/// Fallo de la API de Places con un motivo que se puede mostrar al usuario.
///
/// Existe porque Places responde 200 incluso cuando rechaza la petición (la
/// llave falta, está restringida o sin facturación): devolver una lista vacía
/// en ese caso hacía que la búsqueda pareciera "sin resultados".
class PlacesException implements Exception {
  const PlacesException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Servicio de autocompletado de direcciones usando Google Places API.
class PlacesService {
  PlacesService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _baseUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  /// Busca sugerencias de direcciones que coincidan con [input].
  ///
  /// [language] por defecto `es` (español).
  /// [country] restringe resultados a un país (ISO 3166-1 alpha-2).
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    String language = 'es',
    String? country,
  }) async {
    if (input.trim().isEmpty) return [];

    final params = <String, String>{
      'input': input,
      'key': apiKey,
      'language': language,
      'types': 'address',
    };
    if (country != null) {
      params['components'] = 'country:$country';
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw PlacesException('Google Places respondió ${response.statusCode}.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final status = json['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final detail = json['error_message'] as String?;
      throw PlacesException(
        switch (status) {
              'REQUEST_DENIED' =>
                'Google rechazó la petición: revisa la llave de API, sus '
                    'restricciones y que la Places API esté habilitada.',
              'OVER_QUERY_LIMIT' => 'Se agotó la cuota de Google Places.',
              'INVALID_REQUEST' => 'Petición inválida a Google Places.',
              _ => 'Google Places devolvió el estado $status.',
            } +
            (detail != null ? '\n$detail' : ''),
      );
    }

    final predictions = json['predictions'] as List<dynamic>? ?? [];

    return predictions.map((p) {
      final pred = p as Map<String, dynamic>;
      final structured =
          pred['structured_formatting'] as Map<String, dynamic>? ?? {};
      return PlacePrediction(
        placeId: pred['place_id'] as String? ?? '',
        description: pred['description'] as String? ?? '',
        mainText: structured['main_text'] as String?,
        secondaryText: structured['secondary_text'] as String?,
      );
    }).toList();
  }
}
