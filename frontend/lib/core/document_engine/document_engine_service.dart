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
      final response = await _client.post<Map<String, dynamic>>(
          '$_baseUrl/v1/assets/$assetId/process',
          options: Options(
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 10)));
      final data = response.data;
      return data == null ? null : DocumentProcessResult.fromJson(data);
    } on DioException {
      return null;
    }
  }

  Future<List<CoreSearchHit>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];
    try {
      final response = await _client.get<List<dynamic>>(
          '$_baseUrl/v1/core/search',
          queryParameters: {'q': query, 'limit': limit},
          options: Options(receiveTimeout: const Duration(seconds: 5)));
      return response.data
              ?.whereType<Map<String, dynamic>>()
              .map(CoreSearchHit.fromJson)
              .toList() ??
          const [];
    } on DioException {
      return const [];
    }
  }

  Future<CoreCapabilities?> capabilities() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
          '$_baseUrl/v1/core/capabilities',
          options: Options(receiveTimeout: const Duration(seconds: 5)));
      final data = response.data;
      return data == null ? null : CoreCapabilities.fromJson(data);
    } on DioException {
      return null;
    }
  }
}
