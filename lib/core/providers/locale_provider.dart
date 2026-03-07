import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Supported app locales with display labels.
enum AppLocale {
  system('System Default', null),
  en('English', Locale('en')),
  nl('Nederlands', Locale('nl')),
  de('Deutsch', Locale('de')),
  fr('Fran\u00e7ais', Locale('fr')),
  hi('\u0939\u093f\u0928\u094d\u0926\u0940', Locale('hi'));

  const AppLocale(this.label, this.locale);

  final String label;
  final Locale? locale;

  /// The language name sent to the AI backend for prompt context.
  String get languageName {
    switch (this) {
      case AppLocale.system:
        return _systemLanguageName();
      case AppLocale.en:
        return 'English';
      case AppLocale.nl:
        return 'Dutch';
      case AppLocale.de:
        return 'German';
      case AppLocale.fr:
        return 'French';
      case AppLocale.hi:
        return 'Hindi';
    }
  }

  static String _systemLanguageName() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    switch (code) {
      case 'nl':
        return 'Dutch';
      case 'de':
        return 'German';
      case 'fr':
        return 'French';
      case 'hi':
        return 'Hindi';
      default:
        return 'English';
    }
  }
}

class LocaleState {
  final AppLocale appLocale;

  const LocaleState({this.appLocale = AppLocale.system});

  /// The effective locale to pass to MaterialApp.
  /// Returns null for system default (lets Flutter resolve it).
  Locale? get locale => appLocale.locale;

  /// The language name for AI prompt context.
  String get languageName => appLocale.languageName;
}

class LocaleNotifier extends StateNotifier<LocaleState> {
  LocaleNotifier() : super(const LocaleState()) {
    _loadSaved();
  }

  static const _boxName = 'settings';
  static const _key = 'app_locale';

  Future<void> _loadSaved() async {
    final box = await Hive.openBox(_boxName);
    final saved = box.get(_key) as String?;
    if (saved != null) {
      final match = AppLocale.values.where((l) => l.name == saved);
      if (match.isNotEmpty) {
        state = LocaleState(appLocale: match.first);
      }
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    state = LocaleState(appLocale: locale);
    final box = await Hive.openBox(_boxName);
    await box.put(_key, locale.name);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, LocaleState>((ref) {
  return LocaleNotifier();
});
