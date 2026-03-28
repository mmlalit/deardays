// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'DearDays';

  @override
  String get settings => 'Einstellungen';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get account => 'KONTO';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get subscription => 'Abonnement';

  @override
  String get manage => 'Verwalten';

  @override
  String get journaling => 'TAGEBUCH';

  @override
  String get dailyReminder => 'Tägliche Erinnerung';

  @override
  String dailyReminderSet(String time) {
    return 'Tägliche Erinnerung auf $time eingestellt';
  }

  @override
  String get writingStyle => 'Schreibstil';

  @override
  String writingStyleUpdated(String style) {
    return 'Schreibstil auf $style aktualisiert';
  }

  @override
  String get writingStyleFailed =>
      'Schreibstil konnte nicht aktualisiert werden.';

  @override
  String get memoir => 'Memoiren';

  @override
  String get memoirDesc => 'Erzählung in der dritten Person, reflektierter Ton';

  @override
  String get diary => 'Tagebuch';

  @override
  String get diaryDesc => 'Erste Person, unge­zwungene tägliche Einträge';

  @override
  String get story => 'Geschichte';

  @override
  String get storyDesc => 'Filmisches Erzählen, lebhafte Szenen';

  @override
  String get chapterOrganization => 'Kapitelorganisation';

  @override
  String get appearance => 'DARSTELLUNG';

  @override
  String get language => 'SPRACHE';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get privacySecurity => 'DATENSCHUTZ & SICHERHEIT';

  @override
  String get biometricLock => 'Biometrische Sperre';

  @override
  String get verifyBiometric =>
      'Bestätigen Sie Ihre Identität, um die biometrische Sperre zu aktivieren';

  @override
  String get pinLock => 'PIN-Sperre';

  @override
  String get patternLock => 'Mustersperre';

  @override
  String get active => 'Aktiv';

  @override
  String get setUp => 'Einrichten';

  @override
  String get encryptionInfo => 'Verschlüsselungsinfo';

  @override
  String get zeroKnowledgeEncryption => 'Zero-Knowledge-Verschlüsselung';

  @override
  String get algorithm => 'Algorithmus';

  @override
  String get keyDerivation => 'Schlüsselableitung';

  @override
  String get salt => 'Salt';

  @override
  String get uniqueSalt => 'Einzigartiger 256-Bit pro Benutzer';

  @override
  String get encryptionExplanation =>
      'Ihr Verschlüsselungsschlüssel wird aus Ihrem Passwort abgeleitet und verlässt nie Ihr Gerät. Der Server speichert nur verschlüsselte Daten — wir können Ihre Tagebucheinträge nicht lesen.';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get data => 'DATEN';

  @override
  String get exportAllData => 'Alle Daten exportieren';

  @override
  String get exportYourData => 'Ihre Daten exportieren';

  @override
  String get exportingData => 'Daten werden exportiert...';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get json => 'JSON';

  @override
  String get jsonDesc => 'Maschinenlesbar, enthält alle Felder';

  @override
  String get pdf => 'PDF';

  @override
  String get pdfDesc => 'Druckfertiges Buchformat';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountTitle => 'Konto löschen?';

  @override
  String get deleteAccountWarning =>
      'Dies löscht Ihr Konto und alle Tagebucheinträge dauerhaft. Diese Aktion kann nicht rückgängig gemacht werden.\n\nIhre verschlüsselten Daten werden vom Server gelöscht.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get deleteEverything => 'Alles löschen';

  @override
  String get typeDeleteToConfirm => 'Tippen Sie DELETE zur Bestätigung';

  @override
  String get confirmDelete => 'Löschung bestätigen';

  @override
  String get deleteAccountFailed =>
      'Konto konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get about => 'ÜBER';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get goodMorning => 'Guten Morgen';

  @override
  String get goodAfternoon => 'Guten Tag';

  @override
  String get goodEvening => 'Guten Abend';

  @override
  String get morning => 'Morgen';

  @override
  String get afternoon => 'Nachmittag';

  @override
  String get evening => 'Abend';

  @override
  String get dailyLimitReached =>
      'Du hast dein heutiges Erinnerungslimit erreicht. Komm morgen wieder!';

  @override
  String get moodGreat => 'großartig';

  @override
  String get moodGood => 'gut';

  @override
  String get moodOkay => 'okay';

  @override
  String get moodLow => 'niedergeschlagen';

  @override
  String get moodTough => 'schwer';

  @override
  String get whatsUp => 'Was gibt\'s Neues?';

  @override
  String get tellMeMore => 'Ich höre dir zu. Erzähl mir mehr darüber.';

  @override
  String get moodGreatResponse =>
      'Das ist toll! Was macht deinen Tag so großartig?';

  @override
  String get moodGoodResponse =>
      'Schön zu hören! Was Gutes ist heute passiert?';

  @override
  String get moodOkayResponse =>
      'Okay. Möchtest du erzählen, was dir durch den Kopf geht?';

  @override
  String get moodLowResponse => 'Das tut mir leid. Was ist passiert?';

  @override
  String get moodToughResponse =>
      'Das klingt schwer. Ich bin für dich da. Möchtest du teilen, was los ist?';

  @override
  String get moodDefaultResponse =>
      'Danke fürs Teilen. Erzähl mir mehr über deinen Tag.';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get newEntry => 'Neuer Eintrag';

  @override
  String get today => 'Heute';

  @override
  String get yesterday => 'Gestern';

  @override
  String daysAgo(int count) {
    return 'Vor $count Tagen';
  }

  @override
  String get weekAgo => 'Vor 1 Woche';

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Monaten',
      one: 'Vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Jahren',
      one: 'Vor 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String get recentMemories => 'Recent Memories';

  @override
  String get viewAll => 'View All';

  @override
  String get journalActivity => 'Journal Activity';

  @override
  String get continueWriting => 'Continue Writing';

  @override
  String get yourStoryStartsHere => 'Your story starts here';

  @override
  String get emptyHomeSubtitle =>
      'Speak, snap, or write your first memory above. It takes less than a minute.';

  @override
  String get startYourDayWithMemory => 'Start your day with a memory';

  @override
  String get captureAMoment => 'Capture a moment from today';

  @override
  String get readyToReflect => 'Ready to reflect on your day?';

  @override
  String get perfectTimeToJournal => 'Perfect time to journal';

  @override
  String get speak => 'Speak';

  @override
  String get write => 'Write';

  @override
  String get checkIn => 'Check In';

  @override
  String get timelineEmptyTitle => 'Your timeline is empty';

  @override
  String get timelineEmptySubtitle =>
      'Start recording memories to see them here.';

  @override
  String get writeFirstMemory => 'Write your first memory';

  @override
  String get notifications => 'NOTIFICATIONS';

  @override
  String get preferences => 'PREFERENCES';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutTitle => 'Sign Out?';

  @override
  String get signOutMessage =>
      'You will need to sign in again to access your journal.';

  @override
  String get welcomeBack => 'Welcome\nback.';

  @override
  String get startYourStory => 'Start your\nstory.';

  @override
  String get everyGreatLife => 'Every great life deserves a journal.';

  @override
  String get pickUpWhereYouLeftOff => 'Pick up where you left off.';

  @override
  String get createAccount => 'Create Account';

  @override
  String get logIn => 'Log In';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get fullName => 'Full name';

  @override
  String get emailAddress => 'Email address';

  @override
  String get passwordPlaceholder => 'Password';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get logInArrow => 'Log in →';

  @override
  String get signUpArrow => 'Sign up →';

  @override
  String get byContAcceptTerms => 'By continuing, you agree to our ';

  @override
  String get terms => 'Terms';

  @override
  String get andWord => ' and ';

  @override
  String get noEntries => 'Noch keine Einträge';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
      zero: 'Keine Einträge',
    );
    return '$_temp0';
  }
}
