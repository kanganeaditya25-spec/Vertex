import 'package:dio/dio.dart';

import '../app_config.dart';
import 'document_engine_models.dart';

class DocumentEngineService {
  DocumentEngineService({Dio? client, String? baseUrl})
      : _client = client ?? Dio(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final Dio _client;
  final String _baseUrl;

  Future<DocumentProcessResult?> processAsset(String assetId) async {
    try {
      final response = await _client.post<dynamic>(
        '$_baseUrl/v1/assets/$assetId/process',
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return DocumentProcessResult.fromJson(data);
    } on DioException catch (_) {
      return null;
    } on FormatException catch (_) {
      return null;
    } on TypeError catch (_) {
      return null;
    }
  }

  Future<List<CoreSearchHit>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];
    try {
      final response = await _client.get<dynamic>(
        '$_baseUrl/v1/core/search',
        queryParameters: {'q': query, 'limit': limit},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(CoreSearchHit.fromJson)
          .toList();
    } on DioException catch (_) {
      return const [];
    } on FormatException catch (_) {
      return const [];
    } on TypeError catch (_) {
      return const [];
    }
  }

  Future<CoreCapabilities?> capabilities() async {
    try {
      final response = await _client.get<dynamic>(
        '$_baseUrl/v1/core/capabilities',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return CoreCapabilities.fromJson(data);
    } on DioException catch (_) {
      return null;
    } on FormatException catch (_) {
      return null;
    } on TypeError catch (_) {
      return null;
    }
  }
}
