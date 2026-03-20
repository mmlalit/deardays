// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DearDays';

  @override
  String get settings => 'Settings';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get account => 'ACCOUNT';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get subscription => 'Subscription';

  @override
  String get manage => 'Manage';

  @override
  String get journaling => 'MEMORIES';

  @override
  String get dailyReminder => 'Daily Reminder';

  @override
  String dailyReminderSet(String time) {
    return 'Daily reminder set for $time';
  }

  @override
  String get writingStyle => 'Writing Style';

  @override
  String writingStyleUpdated(String style) {
    return 'Writing style updated to $style';
  }

  @override
  String get writingStyleFailed => 'Failed to update writing style.';

  @override
  String get memoir => 'Memoir';

  @override
  String get memoirDesc => 'Third-person narrative, reflective tone';

  @override
  String get diary => 'Diary';

  @override
  String get diaryDesc => 'First-person, casual daily entries';

  @override
  String get story => 'Story';

  @override
  String get storyDesc => 'Cinematic storytelling, vivid scenes';

  @override
  String get chapterOrganization => 'Chapter Organization';

  @override
  String get appearance => 'APPEARANCE';

  @override
  String get language => 'LANGUAGE';

  @override
  String get appLanguage => 'App Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get privacySecurity => 'PRIVACY & SECURITY';

  @override
  String get biometricLock => 'Biometric Lock';

  @override
  String get verifyBiometric => 'Verify your identity to enable biometric lock';

  @override
  String get pinLock => 'PIN Lock';

  @override
  String get patternLock => 'Pattern Lock';

  @override
  String get active => 'Active';

  @override
  String get setUp => 'Set up';

  @override
  String get encryptionInfo => 'Encryption Info';

  @override
  String get zeroKnowledgeEncryption => 'Zero-Knowledge Encryption';

  @override
  String get algorithm => 'Algorithm';

  @override
  String get keyDerivation => 'Key Derivation';

  @override
  String get salt => 'Salt';

  @override
  String get uniqueSalt => 'Unique 256-bit per user';

  @override
  String get encryptionExplanation =>
      'Your encryption key is derived from your password and never leaves your device. The server stores only encrypted blobs — we cannot read your memories.';

  @override
  String get gotIt => 'Got it';

  @override
  String get data => 'DATA';

  @override
  String get exportAllData => 'Export All Data';

  @override
  String get exportYourData => 'Export Your Data';

  @override
  String get exportingData => 'Exporting your data...';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get json => 'JSON';

  @override
  String get jsonDesc => 'Machine-readable, includes all fields';

  @override
  String get pdf => 'PDF';

  @override
  String get pdfDesc => 'Print-ready book format';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountTitle => 'Delete Account?';

  @override
  String get deleteAccountWarning =>
      'This will permanently delete your account and all your memories. This action cannot be undone.\n\nYour encrypted data will be erased from the server.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteEverything => 'Delete Everything';

  @override
  String get typeDeleteToConfirm => 'Type DELETE to confirm';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get deleteAccountFailed =>
      'Failed to delete account. Please try again.';

  @override
  String get about => 'ABOUT';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get goodMorning => 'Good Morning';

  @override
  String get goodAfternoon => 'Good Afternoon';

  @override
  String get goodEvening => 'Good Evening';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get dailyLimitReached =>
      'You\'ve reached today\'s memory limit. Come back tomorrow!';

  @override
  String get moodGreat => 'great';

  @override
  String get moodGood => 'good';

  @override
  String get moodOkay => 'okay';

  @override
  String get moodLow => 'low';

  @override
  String get moodTough => 'tough';

  @override
  String get whatsUp => 'What\'s up?';

  @override
  String get tellMeMore => 'I hear you. Tell me more about that.';

  @override
  String get moodGreatResponse =>
      'That\'s amazing! What\'s making your day so great?';

  @override
  String get moodGoodResponse =>
      'Nice to hear! What good things happened today?';

  @override
  String get moodOkayResponse =>
      'Fair enough. Want to talk about what\'s on your mind?';

  @override
  String get moodLowResponse =>
      'I\'m sorry you\'re feeling low. What happened?';

  @override
  String get moodToughResponse =>
      'That sounds hard. I\'m here for you. Want to share what\'s going on?';

  @override
  String get moodDefaultResponse =>
      'Thanks for sharing. Tell me more about your day.';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get newEntry => 'New Entry';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get weekAgo => '1 week ago';

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get noEntries => 'No entries yet';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'No entries',
    );
    return '$_temp0';
  }
}
