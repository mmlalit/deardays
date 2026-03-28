import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/ai/ai_prompts.dart';
import 'package:deardays/services/ai/prompt_sanitizer.dart';

/// Streaming AI service that returns tokens as they arrive via SSE.
///
/// This gives users immediate visual feedback instead of waiting 5-15s
/// for a complete response. The full text appears word-by-word.
///
/// Usage:
/// ```dart
/// final stream = AiStreamService().streamPolish(rawText);
/// await for (final chunk in stream) {
///   setState(() => displayText += chunk);
/// }
/// ```
class AiStreamService {
  AiStreamService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  static final AiStreamService _instance = AiStreamService._internal();
  factory AiStreamService() => _instance;

  late final Dio _dio;

  static const String _apiBaseUrl = String.fromEnvironment(
    'AI_API_URL',
    defaultValue: '',
  );

  bool get isConfigured => _apiBaseUrl.isNotEmpty;

  /// Streams a light polish response token-by-token.
  Stream<String> streamPolish(String rawText, {String? language}) {
    return _streamRequest('/ai-polish', {
      'text': PromptSanitizer.sanitize(rawText),
      'style': 'clean',
      'system_prompt': AiPrompts.polishClean,
      'stream': true,
      if (language != null) 'language': language,
    });
  }

  /// Streams a narrative polish response token-by-token.
  Stream<String> streamNarrative(
    String rawText, {
    String style = 'memoir',
    String? language,
  }) {
    return _streamRequest('/ai-polish', {
      'text': PromptSanitizer.sanitize(rawText),
      'style': style,
      'system_prompt': AiPrompts.polishMemoir,
      'stream': true,
      if (language != null) 'language': language,
    });
  }

  /// Streams a chat response token-by-token.
  Stream<String> streamChat({
    required List<Map<String, String>> messages,
    String? mood,
    bool isFirstCheckIn = false,
    String? language,
  }) {
    // Sanitize user-provided text in chat messages.
    final sanitizedMessages = messages.map((m) {
      if (m['role'] == 'user' && m['content'] != null) {
        return {...m, 'content': PromptSanitizer.sanitize(m['content']!)};
      }
      return m;
    }).toList();
    return _streamRequest('/ai-chat', {
      'messages': sanitizedMessages,
      'mood': mood,
      'is_first_checkin': isFirstCheckIn,
      'stream': true,
      if (language != null) 'language': language,
    });
  }

  /// Core SSE streaming implementation.
  ///
  /// Sends a POST request with `stream: true` and parses the response as
  /// Server-Sent Events (SSE). Each `data:` line contains a JSON object
  /// with a `text` field containing the next token(s).
  Stream<String> _streamRequest(
    String path,
    Map<String, dynamic> data,
  ) async* {
    if (!isConfigured) {
      throw AiStreamException('AI_API_URL is not configured.');
    }

    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: data,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw AiStreamException('No response stream received.');
      }

      // Buffer for incomplete SSE lines
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);

        // Process complete SSE lines
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.isEmpty) continue;
          if (line == 'data: [DONE]') return;

          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
              final text = parsed['text'] as String?;
              if (text != null && text.isNotEmpty) {
                yield text;
              }
            } catch (e) {
              // Partial JSON or non-JSON data line — skip
              if (kDebugMode) {
                debugPrint('[AiStreamService] Skipping unparseable SSE: $jsonStr');
              }
            }
          }
        }
      }
    } on DioException catch (e) {
      throw AiStreamException(
        'Stream request failed: ${e.type.name} - ${e.message}',
      );
    }
  }
}

class AiStreamException implements Exception {
  final String message;
  AiStreamException(this.message);

  @override
  String toString() => 'AiStreamException: $message';
}
