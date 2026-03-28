/// Typed route path constants to eliminate magic strings.
///
/// TODO: Migrate all raw string route paths in GoRouter config and navigation
/// calls to use these AppRoutes constants for consistency and refactor safety.
///
/// Usage:
/// ```dart
/// context.go(AppRoutes.home);
/// context.push(AppRoutes.bookDetail); // with extra
/// context.push(AppRoutes.book('abc-123')); // parameterized
/// ```
abstract final class AppRoutes {
  // ── Shell tabs ──────────────────────────────────────────────────────────
  static const home = '/home';
  static const book = '/book';
  static const timeline = '/timeline';
  static const explore = '/explore';
  static const settings = '/settings';

  // ── Auth / onboarding ──────────────────────────────────────────────────
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const setPassphrase = '/set-passphrase';

  // ── Journal flow ───────────────────────────────────────────────────────
  static const record = '/record';
  static const write = '/write';
  static const processing = '/processing';
  static const review = '/review';
  static const editMemory = '/edit-memory';
  static const postSave = '/post-save';

  // ── Entry detail ───────────────────────────────────────────────────────
  static const memory = '/memory';
  static const onThisDay = '/on-this-day';
  static const shareCard = '/share-card';

  // ── Books / chapters ───────────────────────────────────────────────────
  static const bookCreate = '/book-create';
  static const bookDetail = '/book-detail';
  static const myLifeBook = '/my-life-book';
  static const export = '/export';

  /// Parameterized book route: `/book/:id`
  static String bookById(String id) => '/book/$id';

  /// Parameterized chapter route: `/chapter/:id`
  static String chapterById(String id) => '/chapter/$id';

  // ── Explore ────────────────────────────────────────────────────────────
  /// Parameterized see-all route: `/explore/see-all/:section`
  static String seeAll(String section) => '/explore/see-all/$section';

  // ── Misc ───────────────────────────────────────────────────────────────
  static const checkin = '/checkin';
  static const paywall = '/paywall';
  static const search = '/search';
  static const weeklyReport = '/weekly-report';
  static const backupRestore = '/backup-restore';
  static const story = '/story';

  /// Reflection route with period query param.
  static String reflection({String period = 'weekly'}) =>
      '/reflection?period=$period';
}
