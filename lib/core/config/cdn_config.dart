/// CDN configuration for media assets.
///
/// When a CDN base URL is configured, all media URLs are rewritten to use
/// the CDN edge instead of Supabase Storage directly. This reduces latency
/// globally (~5-10x faster for users far from the Supabase region).
///
/// Configure via dart-define:
/// ```bash
/// flutter run --dart-define=CDN_BASE_URL=https://cdn.deardays.app
/// ```
///
/// CDN setup (Cloudflare recommended):
/// 1. Create a Cloudflare zone for your domain
/// 2. Add a CNAME record: cdn.deardays.app → `<supabase-project>`.supabase.co
/// 3. Enable caching for /storage/v1/object/public/* paths
/// 4. Set cache TTL: 30 days for images, 7 days for audio
/// 5. Enable Cloudflare Polish (image optimization) on Pro plan
class CdnConfig {
  CdnConfig._();

  /// CDN base URL. When empty, media URLs use Supabase Storage directly.
  static const String cdnBaseUrl = String.fromEnvironment(
    'CDN_BASE_URL',
    defaultValue: '',
  );

  /// Whether CDN is configured.
  static bool get isEnabled => cdnBaseUrl.isNotEmpty;

  /// Rewrites a Supabase Storage URL to use the CDN.
  ///
  /// Input:  https://xxx.supabase.co/storage/v1/object/public/entry-media/user/file.jpg
  /// Output: https://cdn.deardays.app/storage/v1/object/public/entry-media/user/file.jpg
  static String rewriteUrl(String supabaseUrl) {
    if (!isEnabled) return supabaseUrl;

    // Extract the path after the Supabase domain
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null) return supabaseUrl;

    return '$cdnBaseUrl${uri.path}';
  }

  /// Generates a CDN-friendly thumbnail URL by appending transform params.
  ///
  /// Supabase Storage supports on-the-fly transforms:
  /// /storage/v1/render/image/public/bucket/path?width=200&height=200
  static String thumbnailUrl(String supabaseUrl, {int width = 200, int height = 200}) {
    final base = isEnabled ? cdnBaseUrl : Uri.tryParse(supabaseUrl)?.origin ?? '';
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null) return supabaseUrl;

    // Replace /object/ with /render/image/ for Supabase image transforms
    final renderPath = uri.path.replaceFirst('/object/', '/render/image/');
    return '$base$renderPath?width=$width&height=$height';
  }
}
