import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

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

  /// Whether the AI backend is configured. When false, all API calls
  /// throw immediately so Dio doesn't fire requests against the host page URL.
  bool get isConfigured => _apiBaseUrl.isNotEmpty;

  void _ensureConfigured(String method) {
    if (!isConfigured) {
      throw AiServiceException(
        '[$method] AI_API_URL is not configured. '
        'Pass --dart-define=AI_API_URL=https://<project-ref>.supabase.co/functions/v1 when building.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Light-polishes raw text: fixes grammar, spelling, and punctuation
  /// while preserving the user's voice and meaning. No literary embellishment.
  Future<String> lightPolish(
    String rawText, {
    String? language,
  }) async {
    _ensureConfigured('lightPolish');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-polish',
        data: {
          'text': rawText,
          'style': 'clean',
          if (language != null) 'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'lightPolish');
    }
  }

  /// Sends raw journal text to the AI and returns a polished narrative.
  ///
  /// [style] defaults to `'memoir'` but can be any supported style such as
  /// `'poetic'`, `'factual'`, etc.
  Future<String> polishNarrative(
    String rawText, {
    String style = 'memoir',
    String? language,
  }) async {
    _ensureConfigured('polishNarrative');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-polish',
        data: {
          'text': rawText,
          'style': style,
          if (language != null) 'language': language,
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
    _ensureConfigured('transcribeAudio');
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFilePath),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-transcribe',
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
    String? language,
  }) async {
    _ensureConfigured('generateSummary');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-summarize',
        data: {
          'entries': entries,
          'period': period,
          if (language != null) 'language': language,
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
    _ensureConfigured('getWritingPrompt');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ai-prompt',
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'getWritingPrompt');
    }
  }

  /// Sends a conversational message and returns the AI's reply.
  ///
  /// [messages] is the conversation history as a list of {role, content} maps.
  /// [mood] is the user's current mood (optional context for the AI).
  /// [isFirstCheckIn] indicates if this is the first check-in of the day.
  /// [language] is the user's preferred language (e.g. 'Dutch', 'German').
  /// The AI will default to this language but mirror the user's language
  /// if they switch mid-conversation.
  Future<String> chat({
    required List<Map<String, String>> messages,
    String? mood,
    bool isFirstCheckIn = false,
    String? language,
  }) async {
    _ensureConfigured('chat');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': messages,
          'mood': mood,
          'is_first_checkin': isFirstCheckIn,
          if (language != null) 'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return _extractText(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'chat');
    }
  }

  /// Generates a short image-search query for a book/chapter title.
  ///
  /// Used to fetch a relevant cover photo from Unsplash/Pexels.
  /// Returns a concise English search phrase (3-5 words).
  Future<String> generateCoverQuery(String bookTitle) async {
    _ensureConfigured('generateCoverQuery');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'user',
              'content':
                  'Generate a short (3-5 word) image search query for a journal book titled "$bookTitle". '
                  'Return ONLY the search phrase, nothing else. '
                  'Make it evocative and suitable for finding a beautiful cover photo. '
                  'Example: "Family Life" → "warm family dinner golden hour"',
            },
          ],
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      return _extractText(response).trim();
    } on DioException catch (e) {
      throw _handleDioError(e, 'generateCoverQuery');
    }
  }

  /// Generates a short, poetic summary of a journal entry for sharing.
  ///
  /// Returns 1-2 evocative sentences (max ~25 words) suitable for a share card.
  Future<String> generateShareSummary(
    String entryText, {
    String? language,
  }) async {
    _ensureConfigured('generateShareSummary');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'user',
              'content':
                  'Summarize this journal entry into 1-2 poetic, shareable sentences. '
                  'Keep it evocative and personal but not too revealing. Max 25 words. '
                  'Return ONLY the summary, nothing else.\n\n$entryText',
            },
          ],
          if (language != null) 'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      return _extractText(response).trim();
    } on DioException catch (e) {
      throw _handleDioError(e, 'generateShareSummary');
    }
  }

  /// Detects recurring themes and patterns across the supplied entries.
  Future<List<String>> detectThemes(List<String> entries) async {
    _ensureConfigured('detectThemes');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-themes',
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
      throw AiServiceException('Unexpected response format from /ai-themes');
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
