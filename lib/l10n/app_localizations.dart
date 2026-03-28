import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('hi'),
    Locale('nl')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DearDays'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get account;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @journaling.
  ///
  /// In en, this message translates to:
  /// **'MEMORIES'**
  String get journaling;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get dailyReminder;

  /// No description provided for @dailyReminderSet.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder set for {time}'**
  String dailyReminderSet(String time);

  /// No description provided for @writingStyle.
  ///
  /// In en, this message translates to:
  /// **'Writing Style'**
  String get writingStyle;

  /// No description provided for @writingStyleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Writing style updated to {style}'**
  String writingStyleUpdated(String style);

  /// No description provided for @writingStyleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update writing style.'**
  String get writingStyleFailed;

  /// No description provided for @memoir.
  ///
  /// In en, this message translates to:
  /// **'Memoir'**
  String get memoir;

  /// No description provided for @memoirDesc.
  ///
  /// In en, this message translates to:
  /// **'Third-person narrative, reflective tone'**
  String get memoirDesc;

  /// No description provided for @diary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get diary;

  /// No description provided for @diaryDesc.
  ///
  /// In en, this message translates to:
  /// **'First-person, casual daily entries'**
  String get diaryDesc;

  /// No description provided for @story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// No description provided for @storyDesc.
  ///
  /// In en, this message translates to:
  /// **'Cinematic storytelling, vivid scenes'**
  String get storyDesc;

  /// No description provided for @chapterOrganization.
  ///
  /// In en, this message translates to:
  /// **'Chapter Organization'**
  String get chapterOrganization;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & SECURITY'**
  String get privacySecurity;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric Lock'**
  String get biometricLock;

  /// No description provided for @verifyBiometric.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to enable biometric lock'**
  String get verifyBiometric;

  /// No description provided for @pinLock.
  ///
  /// In en, this message translates to:
  /// **'PIN Lock'**
  String get pinLock;

  /// No description provided for @patternLock.
  ///
  /// In en, this message translates to:
  /// **'Pattern Lock'**
  String get patternLock;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @encryptionInfo.
  ///
  /// In en, this message translates to:
  /// **'Encryption Info'**
  String get encryptionInfo;

  /// No description provided for @zeroKnowledgeEncryption.
  ///
  /// In en, this message translates to:
  /// **'Zero-Knowledge Encryption'**
  String get zeroKnowledgeEncryption;

  /// No description provided for @algorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get algorithm;

  /// No description provided for @keyDerivation.
  ///
  /// In en, this message translates to:
  /// **'Key Derivation'**
  String get keyDerivation;

  /// No description provided for @salt.
  ///
  /// In en, this message translates to:
  /// **'Salt'**
  String get salt;

  /// No description provided for @uniqueSalt.
  ///
  /// In en, this message translates to:
  /// **'Unique 256-bit per user'**
  String get uniqueSalt;

  /// No description provided for @encryptionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your encryption key is derived from your password and never leaves your device. The server stores only encrypted blobs — we cannot read your memories.'**
  String get encryptionExplanation;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'DATA'**
  String get data;

  /// No description provided for @exportAllData.
  ///
  /// In en, this message translates to:
  /// **'Export All Data'**
  String get exportAllData;

  /// No description provided for @exportYourData.
  ///
  /// In en, this message translates to:
  /// **'Export Your Data'**
  String get exportYourData;

  /// No description provided for @exportingData.
  ///
  /// In en, this message translates to:
  /// **'Exporting your data...'**
  String get exportingData;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @json.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get json;

  /// No description provided for @jsonDesc.
  ///
  /// In en, this message translates to:
  /// **'Machine-readable, includes all fields'**
  String get jsonDesc;

  /// No description provided for @pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @pdfDesc.
  ///
  /// In en, this message translates to:
  /// **'Print-ready book format'**
  String get pdfDesc;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all your memories. This action cannot be undone.\n\nYour encrypted data will be erased from the server.'**
  String get deleteAccountWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get deleteEverything;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get typeDeleteToConfirm;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @dailyLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s memory limit. Come back tomorrow!'**
  String get dailyLimitReached;

  /// No description provided for @moodGreat.
  ///
  /// In en, this message translates to:
  /// **'great'**
  String get moodGreat;

  /// No description provided for @moodGood.
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get moodGood;

  /// No description provided for @moodOkay.
  ///
  /// In en, this message translates to:
  /// **'okay'**
  String get moodOkay;

  /// No description provided for @moodLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get moodLow;

  /// No description provided for @moodTough.
  ///
  /// In en, this message translates to:
  /// **'tough'**
  String get moodTough;

  /// No description provided for @whatsUp.
  ///
  /// In en, this message translates to:
  /// **'What\'s up?'**
  String get whatsUp;

  /// No description provided for @tellMeMore.
  ///
  /// In en, this message translates to:
  /// **'I hear you. Tell me more about that.'**
  String get tellMeMore;

  /// No description provided for @moodGreatResponse.
  ///
  /// In en, this message translates to:
  /// **'That\'s amazing! What\'s making your day so great?'**
  String get moodGreatResponse;

  /// No description provided for @moodGoodResponse.
  ///
  /// In en, this message translates to:
  /// **'Nice to hear! What good things happened today?'**
  String get moodGoodResponse;

  /// No description provided for @moodOkayResponse.
  ///
  /// In en, this message translates to:
  /// **'Fair enough. Want to talk about what\'s on your mind?'**
  String get moodOkayResponse;

  /// No description provided for @moodLowResponse.
  ///
  /// In en, this message translates to:
  /// **'I\'m sorry you\'re feeling low. What happened?'**
  String get moodLowResponse;

  /// No description provided for @moodToughResponse.
  ///
  /// In en, this message translates to:
  /// **'That sounds hard. I\'m here for you. Want to share what\'s going on?'**
  String get moodToughResponse;

  /// No description provided for @moodDefaultResponse.
  ///
  /// In en, this message translates to:
  /// **'Thanks for sharing. Tell me more about your day.'**
  String get moodDefaultResponse;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @newEntry.
  ///
  /// In en, this message translates to:
  /// **'New Entry'**
  String get newEntry;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @weekAgo.
  ///
  /// In en, this message translates to:
  /// **'1 week ago'**
  String get weekAgo;

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String monthsAgo(int count);

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String yearsAgo(int count);

  /// Home screen section header for recent memories
  ///
  /// In en, this message translates to:
  /// **'Recent Memories'**
  String get recentMemories;

  /// Link text to view all items
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// Home screen journal activity card title
  ///
  /// In en, this message translates to:
  /// **'Journal Activity'**
  String get journalActivity;

  /// Home screen drafts section title
  ///
  /// In en, this message translates to:
  /// **'Continue Writing'**
  String get continueWriting;

  /// Home screen empty state title
  ///
  /// In en, this message translates to:
  /// **'Your story starts here'**
  String get yourStoryStartsHere;

  /// Home screen empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Speak, snap, or write your first memory above. It takes less than a minute.'**
  String get emptyHomeSubtitle;

  /// Morning tagline on home screen
  ///
  /// In en, this message translates to:
  /// **'Start your day with a memory'**
  String get startYourDayWithMemory;

  /// Afternoon tagline on home screen
  ///
  /// In en, this message translates to:
  /// **'Capture a moment from today'**
  String get captureAMoment;

  /// Evening tagline on home screen
  ///
  /// In en, this message translates to:
  /// **'Ready to reflect on your day?'**
  String get readyToReflect;

  /// Late evening tagline on home screen
  ///
  /// In en, this message translates to:
  /// **'Perfect time to journal'**
  String get perfectTimeToJournal;

  /// Speak capture button label
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get speak;

  /// Write capture button label
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// Check-in capture button label
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkIn;

  /// Timeline empty state title
  ///
  /// In en, this message translates to:
  /// **'Your timeline is empty'**
  String get timelineEmptyTitle;

  /// Timeline empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Start recording memories to see them here.'**
  String get timelineEmptySubtitle;

  /// Timeline empty state CTA button
  ///
  /// In en, this message translates to:
  /// **'Write your first memory'**
  String get writeFirstMemory;

  /// Settings section header for notifications
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get notifications;

  /// Settings section header for preferences
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// Sign out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutTitle;

  /// Sign out confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to access your journal.'**
  String get signOutMessage;

  /// Login screen title for returning users
  ///
  /// In en, this message translates to:
  /// **'Welcome\nback.'**
  String get welcomeBack;

  /// Login screen title for new users
  ///
  /// In en, this message translates to:
  /// **'Start your\nstory.'**
  String get startYourStory;

  /// Signup screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Every great life deserves a journal.'**
  String get everyGreatLife;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off.'**
  String get pickUpWhereYouLeftOff;

  /// Signup button label
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Login button label
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Name field placeholder on signup
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// Email field placeholder
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// Password field placeholder
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordPlaceholder;

  /// Toggle to login text prefix
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// Toggle to signup text prefix
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// Toggle to login link text
  ///
  /// In en, this message translates to:
  /// **'Log in →'**
  String get logInArrow;

  /// Toggle to signup link text
  ///
  /// In en, this message translates to:
  /// **'Sign up →'**
  String get signUpArrow;

  /// Legal disclaimer prefix
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get byContAcceptTerms;

  /// Terms of service link text
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// Conjunction between Terms and Privacy
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andWord;

  /// No description provided for @noEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get noEntries;

  /// No description provided for @entriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No entries} =1{1 entry} other{{count} entries}}'**
  String entriesCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'hi', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
