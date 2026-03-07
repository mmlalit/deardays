import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI service for narrative generation, transcription, and writing assistance.
///
/// All text passed to this service must already be decrypted in memory.
/// Encryption keys are NEVER sent to the AI backend.
class AiService {
  AiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Attach Supabase auth token to every request.
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('[AiService] ${options.method} ${options.uri}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[AiService] ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              '[AiService] ERROR ${error.type}: ${error.message}',
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  static final AiService _instance = AiService._internal();

  /// Singleton accessor.
  static AiService get instance => _instance;

  factory AiService() => _instance;

  late final Dio _dio;

  static const String _apiBaseUrl = String.fromEnvironment(
    'AI_API_URL',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sends raw journal text to the AI and returns a polished narrative.
  ///
  /// [style] defaults to `'memoir'` but can be any supported style such as
  /// `'poetic'`, `'factual'`, etc.
  Future<String> polishNarrative(
    String rawText, {
    String style = 'memoir',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/polish',
        data: {
          'text': rawText,
          'style': style,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'polishNarrative');
    }
  }

  /// Sends an audio file for Whisper transcription and returns the transcript.
  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFilePath),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/transcribe',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'transcribeAudio');
    }
  }

  /// Sends multiple journal entries and returns a summary for the given
  /// [period] (e.g. `'weekly'`, `'monthly'`).
  Future<String> generateSummary(
    List<String> entries, {
    String period = 'weekly',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/summarize',
        data: {
          'entries': entries,
          'period': period,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'generateSummary');
    }
  }

  /// Returns a creative writing prompt from the AI backend.
  Future<String> getWritingPrompt() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/prompt',
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'getWritingPrompt');
    }
  }

  /// Detects recurring themes and patterns across the supplied entries.
  Future<List<String>> detectThemes(List<String> entries) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/themes',
        data: {
          'entries': entries,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data;
      if (data != null && data.containsKey('themes')) {
        return List<String>.from(data['themes'] as List);
      }
      throw AiServiceException('Unexpected response format from /api/themes');
    } on DioException catch (e) {
      throw _handleDioError(e, 'detectThemes');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extracts the `text` field from a standard JSON response.
  String _extractText(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data != null && data.containsKey('text')) {
      return data['text'] as String;
    }
    throw AiServiceException(
      'Unexpected response format: missing "text" field',
    );
  }

  /// Maps [DioException] types to a readable [AiServiceException].
  AiServiceException _handleDioError(DioException e, String method) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AiServiceException(
          '[$method] Request timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return AiServiceException(
          '[$method] Network error. Check your internet connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map
            ? (e.response!.data as Map)['error'] ?? e.message
            : e.message;
        return AiServiceException(
          '[$method] API error ($statusCode): $message',
        );
      default:
        return AiServiceException(
          '[$method] Unexpected error: ${e.message}',
        );
    }
  }
}

/// Exception thrown by [AiService] operations.
class AiServiceException implements Exception {
  AiServiceException(this.message);

  final String message;

  @override
  String toString() => 'AiServiceException: $message';
}
