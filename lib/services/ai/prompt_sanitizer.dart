/// Strips prompt injection attempts from user-supplied text before it is
/// forwarded to the AI backend.
///
/// Injection patterns are replaced with `[removed]` rather than silently
/// dropped so that the surrounding narrative context is preserved.
class PromptSanitizer {
  PromptSanitizer._();

  static final _injectionPatterns = RegExp(
    r'ignore\s+(all\s+)?(previous|prior|above)\s+instructions?'
    r'|system\s*:\s*'
    r'|<\s*\/?\s*system\s*>'
    r'|<\s*\/?\s*assistant\s*>'
    r'|<\s*\/?\s*user\s*>'
    r'|prompt\s+injection'
    r'|disregard\s+(all\s+)?instructions?'
    r'|you\s+are\s+now\s+(a|an)\s+\w+'
    r'|act\s+as\s+(a|an|if)\s+\w+',
    caseSensitive: false,
  );

  /// Returns [text] with known injection patterns replaced by `[removed]`.
  static String sanitize(String text) =>
      text.replaceAll(_injectionPatterns, '[removed]');
}
