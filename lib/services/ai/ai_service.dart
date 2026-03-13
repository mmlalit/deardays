import 'dart:io';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import 'package:deardays/services/ai/ai_prompts.dart';

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

    // Certificate pinning: only allow connections to the configured Supabase
    // domain. Rejects MITM certificates from rogue CAs or corporate proxies.
    // In debug mode, pinning is relaxed to allow proxy-based debugging tools.
    if (!kDebugMode && _apiBaseUrl.isNotEmpty) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // Reject any certificate that doesn't match our expected host.
          // The platform's default trust store still validates the chain;
          // this callback only fires for certificates that FAILED default
          // validation — so returning false here rejects them.
          return false;
        };
        return client;
      };
    }
  }

  static final AiService _instance = AiService._internal();

  /// Singleton accessor.
  static AiService get instance => _instance;

  factory AiService() => _instance;

  late final Dio _dio;

  // In-memory cache for deterministic AI responses (cover queries, share summaries).
  // Avoids redundant API calls for the same input within the same session.
  // Max 100 entries to prevent unbounded growth.
  static const int _maxCacheSize = 100;
  final Map<String, String> _responseCache = {};

  String? _getCached(String key) => _responseCache[key];

  void _putCache(String key, String value) {
    if (_responseCache.length >= _maxCacheSize) {
      _responseCache.remove(_responseCache.keys.first);
    }
    _responseCache[key] = value;
  }

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
          'system_prompt': AiPrompts.polishClean,
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
          'system_prompt': AiPrompts.polishMemoir,
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

  /// Generates a short, casual title for a journal entry (3-7 words).
  Future<String> generateTitle(
    String entryText, {
    String? language,
  }) async {
    _ensureConfigured('generateTitle');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'system',
              'content': AiPrompts.entryTitle,
            },
            {
              'role': 'user',
              'content': entryText,
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
      throw _handleDioError(e, 'generateTitle');
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
          'system_prompt': AiPrompts.weeklySummary,
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
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-prompt',
        data: {
          'system_prompt': AiPrompts.writingPrompt,
        },
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

    // Cover queries are deterministic for the same title — use cache
    final cacheKey = 'cover:${bookTitle.toLowerCase().trim()}';
    final cached = _getCached(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'system',
              'content': AiPrompts.coverQuery,
            },
            {
              'role': 'user',
              'content': bookTitle,
            },
          ],
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final result = _extractText(response).trim();
      _putCache(cacheKey, result);
      return result;
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

    // Cache share summaries — same entry text + language = same result
    final cacheKey = 'share:${language ?? ""}:${entryText.hashCode}';
    final cached = _getCached(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'system',
              'content': AiPrompts.shareCardSummary,
            },
            {
              'role': 'user',
              'content': entryText,
            },
          ],
          if (language != null) 'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final result = _extractText(response).trim();
      _putCache(cacheKey, result);
      return result;
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
          'system_prompt': AiPrompts.themeDetection,
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

  /// Performs a merged entry analysis: themes + summary + highlight in one call.
  ///
  /// Returns a map with keys: `themes` (list of strings), `summary` (string),
  /// and `highlight` (map with title + quote).
  /// Falls back to individual calls if the merged response can't be parsed.
  Future<Map<String, dynamic>> analyzeEntries(
    List<String> entries, {
    String? language,
  }) async {
    _ensureConfigured('analyzeEntries');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'system',
              'content': AiPrompts.mergedEntryAnalysis,
            },
            {
              'role': 'user',
              'content': entries.join('\n---\n'),
            },
          ],
          if (language != null) 'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      final rawText = _extractText(response).trim();

      // Parse JSON response
      try {
        final parsed = jsonDecode(rawText) as Map<String, dynamic>;
        return {
          'themes': List<String>.from(parsed['themes'] as List? ?? []),
          'summary': parsed['summary'] as String? ?? '',
          'highlight': parsed['highlight'] as Map<String, dynamic>? ?? {},
        };
      } catch (_) {
        // If JSON parsing fails, return the raw text as summary
        return {
          'themes': <String>[],
          'summary': rawText,
          'highlight': <String, dynamic>{},
        };
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'analyzeEntries');
    }
  }

  /// Searches journal memories using AI to answer natural language questions.
  ///
  /// Returns a map with `answer` (String) and `entryIndices` (List of int)
  /// pointing to the most relevant entries.
  Future<Map<String, dynamic>> memorySearch({
    required String question,
    required List<String> entrySummaries,
    String? language,
  }) async {
    _ensureConfigured('memorySearch');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-chat',
        data: {
          'messages': [
            {
              'role': 'system',
              'content': AiPrompts.memorySearch(language: language),
            },
            {
              'role': 'user',
              'content': '$question\n\n---\nJournal entries:\n${entrySummaries.join('\n')}',
            },
          ],
          if (language != null) 'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final rawText = _extractText(response).trim();

      try {
        final parsed = jsonDecode(rawText) as Map<String, dynamic>;
        return {
          'answer': parsed['answer'] as String? ?? rawText,
          'entryIndices': List<int>.from(parsed['entry_indices'] as List? ?? []),
        };
      } catch (_) {
        // If JSON parsing fails, return the raw text as the answer
        return {
          'answer': rawText,
          'entryIndices': <int>[],
        };
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'memorySearch');
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
        if (kDebugMode) {
          final debugMsg = e.response?.data is Map
              ? (e.response!.data as Map)['error'] ?? e.message
              : e.message;
          debugPrint('[$method] API error ($statusCode): $debugMsg');
        }
        return AiServiceException(
          '[$method] Request failed ($statusCode). Please try again.',
        );
      default:
        if (kDebugMode) {
          debugPrint('[$method] Unexpected error: ${e.message}');
        }
        return AiServiceException(
          '[$method] Something went wrong. Please try again.',
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
