// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'DearDays';

  @override
  String get settings => 'Instellingen';

  @override
  String get editProfile => 'Profiel bewerken';

  @override
  String get account => 'ACCOUNT';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Wachtwoord';

  @override
  String get subscription => 'Abonnement';

  @override
  String get manage => 'Beheren';

  @override
  String get journaling => 'DAGBOEK';

  @override
  String get dailyReminder => 'Dagelijkse herinnering';

  @override
  String dailyReminderSet(String time) {
    return 'Dagelijkse herinnering ingesteld op $time';
  }

  @override
  String get writingStyle => 'Schrijfstijl';

  @override
  String writingStyleUpdated(String style) {
    return 'Schrijfstijl bijgewerkt naar $style';
  }

  @override
  String get writingStyleFailed => 'Schrijfstijl bijwerken mislukt.';

  @override
  String get memoir => 'Memoir';

  @override
  String get memoirDesc => 'Derde persoon, reflectieve toon';

  @override
  String get diary => 'Dagboek';

  @override
  String get diaryDesc => 'Eerste persoon, informele dagelijkse verslagen';

  @override
  String get story => 'Verhaal';

  @override
  String get storyDesc => 'Filmisch vertellen, levendige scenes';

  @override
  String get chapterOrganization => 'Hoofdstukindeling';

  @override
  String get appearance => 'UITERLIJK';

  @override
  String get language => 'TAAL';

  @override
  String get appLanguage => 'App-taal';

  @override
  String get systemDefault => 'Systeemstandaard';

  @override
  String get privacySecurity => 'PRIVACY & BEVEILIGING';

  @override
  String get biometricLock => 'Biometrische vergrendeling';

  @override
  String get verifyBiometric =>
      'Verifieer uw identiteit om biometrische vergrendeling in te schakelen';

  @override
  String get pinLock => 'PIN-vergrendeling';

  @override
  String get patternLock => 'Patroonvergrendeling';

  @override
  String get active => 'Actief';

  @override
  String get setUp => 'Instellen';

  @override
  String get encryptionInfo => 'Versleutelingsinfo';

  @override
  String get zeroKnowledgeEncryption => 'Zero-Knowledge Versleuteling';

  @override
  String get algorithm => 'Algoritme';

  @override
  String get keyDerivation => 'Sleutelafleiding';

  @override
  String get salt => 'Salt';

  @override
  String get uniqueSalt => 'Unieke 256-bit per gebruiker';

  @override
  String get encryptionExplanation =>
      'Uw versleutelingssleutel is afgeleid van uw wachtwoord en verlaat nooit uw apparaat. De server slaat alleen versleutelde gegevens op — wij kunnen uw dagboekverslagen niet lezen.';

  @override
  String get gotIt => 'Begrepen';

  @override
  String get data => 'GEGEVENS';

  @override
  String get exportAllData => 'Alle gegevens exporteren';

  @override
  String get exportYourData => 'Uw gegevens exporteren';

  @override
  String get exportingData => 'Gegevens worden geëxporteerd...';

  @override
  String exportFailed(String error) {
    return 'Export mislukt: $error';
  }

  @override
  String get json => 'JSON';

  @override
  String get jsonDesc => 'Machineleesbaar, bevat alle velden';

  @override
  String get pdf => 'PDF';

  @override
  String get pdfDesc => 'Printklaar boekformaat';

  @override
  String get deleteAccount => 'Account verwijderen';

  @override
  String get deleteAccountTitle => 'Account verwijderen?';

  @override
  String get deleteAccountWarning =>
      'Dit verwijdert permanent uw account en alle dagboekverslagen. Deze actie kan niet ongedaan worden gemaakt.\n\nUw versleutelde gegevens worden van de server gewist.';

  @override
  String get cancel => 'Annuleren';

  @override
  String get deleteEverything => 'Alles verwijderen';

  @override
  String get typeDeleteToConfirm => 'Typ DELETE om te bevestigen';

  @override
  String get confirmDelete => 'Verwijdering bevestigen';

  @override
  String get deleteAccountFailed =>
      'Account verwijderen mislukt. Probeer het opnieuw.';

  @override
  String get about => 'OVER';

  @override
  String get version => 'Versie';

  @override
  String get privacyPolicy => 'Privacybeleid';

  @override
  String get termsOfService => 'Servicevoorwaarden';

  @override
  String get goodMorning => 'Goedemorgen';

  @override
  String get goodAfternoon => 'Goedemiddag';

  @override
  String get goodEvening => 'Goedenavond';

  @override
  String get morning => 'Ochtend';

  @override
  String get afternoon => 'Middag';

  @override
  String get evening => 'Avond';

  @override
  String get dailyLimitReached =>
      'Je hebt de dagelijkse geheugenlimiet bereikt. Kom morgen terug!';

  @override
  String get moodGreat => 'geweldig';

  @override
  String get moodGood => 'goed';

  @override
  String get moodOkay => 'oké';

  @override
  String get moodLow => 'down';

  @override
  String get moodTough => 'zwaar';

  @override
  String get whatsUp => 'Hoe gaat het?';

  @override
  String get tellMeMore => 'Ik hoor je. Vertel me er meer over.';

  @override
  String get moodGreatResponse => 'Geweldig! Wat maakt je dag zo fantastisch?';

  @override
  String get moodGoodResponse =>
      'Fijn om te horen! Wat voor goede dingen zijn er vandaag gebeurd?';

  @override
  String get moodOkayResponse =>
      'Oké. Wil je vertellen wat er door je heen gaat?';

  @override
  String get moodLowResponse =>
      'Wat vervelend dat je je zo voelt. Wat is er gebeurd?';

  @override
  String get moodToughResponse =>
      'Dat klinkt zwaar. Ik ben er voor je. Wil je delen wat er aan de hand is?';

  @override
  String get moodDefaultResponse =>
      'Bedankt voor het delen. Vertel me meer over je dag.';

  @override
  String get save => 'Opslaan';

  @override
  String get delete => 'Verwijderen';

  @override
  String get newEntry => 'Nieuw item';

  @override
  String get today => 'Vandaag';

  @override
  String get yesterday => 'Gisteren';

  @override
  String daysAgo(int count) {
    return '$count dagen geleden';
  }

  @override
  String get weekAgo => '1 week geleden';

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count maanden geleden',
      one: '1 maand geleden',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jaar geleden',
      one: '1 jaar geleden',
    );
    return '$_temp0';
  }

  @override
  String get noEntries => 'Nog geen items';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'Geen items',
    );
    return '$_temp0';
  }
}
