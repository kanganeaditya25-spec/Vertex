import 'package:dio/dio.dart';

class AiInsightService {
  AiInsightService({Dio? client, this.baseUrl = 'http://127.0.0.1:11434', this.model = 'gemma3'}) : _client = client ?? Dio();

  final Dio _client;
  final String baseUrl;
  final String model;

  Future<bool> isAvailable() async {
    try {
      final response = await _client.get('$baseUrl/api/tags', options: Options(sendTimeout: const Duration(seconds: 2), receiveTimeout: const Duration(seconds: 2)));
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  Future<String?> generate(String prompt) async {
    try {
      final response = await _client.post(
        '$baseUrl/api/generate',
        data: {'model': model, 'prompt': prompt, 'stream': false},
        options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 90)),
      );
      final value = response.data is Map ? response.data['response'] : null;
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    } on DioException {
      return null;
    }
  }
}
