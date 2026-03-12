// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'DearDays';

  @override
  String get settings => 'Paramètres';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get account => 'COMPTE';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get subscription => 'Abonnement';

  @override
  String get manage => 'Gérer';

  @override
  String get journaling => 'JOURNAL';

  @override
  String get dailyReminder => 'Rappel quotidien';

  @override
  String dailyReminderSet(String time) {
    return 'Rappel quotidien réglé à $time';
  }

  @override
  String get writingStyle => 'Style d\'écriture';

  @override
  String writingStyleUpdated(String style) {
    return 'Style d\'écriture mis à jour : $style';
  }

  @override
  String get writingStyleFailed =>
      'Échec de la mise à jour du style d\'écriture.';

  @override
  String get memoir => 'Mémoires';

  @override
  String get memoirDesc => 'Récit à la troisième personne, ton réflexif';

  @override
  String get diary => 'Journal intime';

  @override
  String get diaryDesc =>
      'Première personne, entrées quotidiennes décontractées';

  @override
  String get story => 'Histoire';

  @override
  String get storyDesc => 'Narration cinématographique, scènes vivantes';

  @override
  String get chapterOrganization => 'Organisation des chapitres';

  @override
  String get appearance => 'APPARENCE';

  @override
  String get language => 'LANGUE';

  @override
  String get appLanguage => 'Langue de l’appli';

  @override
  String get systemDefault => 'Par défaut du système';

  @override
  String get privacySecurity => 'CONFIDENTIALITÉ & SÉCURITÉ';

  @override
  String get biometricLock => 'Verrouillage biométrique';

  @override
  String get verifyBiometric =>
      'Vérifiez votre identité pour activer le verrouillage biométrique';

  @override
  String get pinLock => 'Verrouillage PIN';

  @override
  String get patternLock => 'Verrouillage par motif';

  @override
  String get active => 'Actif';

  @override
  String get setUp => 'Configurer';

  @override
  String get encryptionInfo => 'Info chiffrement';

  @override
  String get zeroKnowledgeEncryption => 'Chiffrement Zero-Knowledge';

  @override
  String get algorithm => 'Algorithme';

  @override
  String get keyDerivation => 'Dérivation de clé';

  @override
  String get salt => 'Sel';

  @override
  String get uniqueSalt => '256 bits unique par utilisateur';

  @override
  String get encryptionExplanation =>
      'Votre clé de chiffrement est dérivée de votre mot de passe et ne quitte jamais votre appareil. Le serveur ne stocke que des données chiffrées — nous ne pouvons pas lire vos entrées de journal.';

  @override
  String get gotIt => 'Compris';

  @override
  String get data => 'DONNÉES';

  @override
  String get exportAllData => 'Exporter toutes les données';

  @override
  String get exportYourData => 'Exporter vos données';

  @override
  String get exportingData => 'Exportation en cours...';

  @override
  String exportFailed(String error) {
    return 'Échec de l’exportation : $error';
  }

  @override
  String get json => 'JSON';

  @override
  String get jsonDesc => 'Lisible par machine, contient tous les champs';

  @override
  String get pdf => 'PDF';

  @override
  String get pdfDesc => 'Format livre prêt à imprimer';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountTitle => 'Supprimer le compte ?';

  @override
  String get deleteAccountWarning =>
      'Cela supprimera définitivement votre compte et toutes vos entrées de journal. Cette action est irréversible.\n\nVos données chiffrées seront effacées du serveur.';

  @override
  String get cancel => 'Annuler';

  @override
  String get deleteEverything => 'Tout supprimer';

  @override
  String get typeDeleteToConfirm => 'Tapez DELETE pour confirmer';

  @override
  String get confirmDelete => 'Confirmer la suppression';

  @override
  String get deleteAccountFailed =>
      'Échec de la suppression du compte. Veuillez réessayer.';

  @override
  String get about => 'À PROPOS';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d’utilisation';

  @override
  String get moodGreat => 'super';

  @override
  String get moodGood => 'bien';

  @override
  String get moodOkay => 'correct';

  @override
  String get moodLow => 'triste';

  @override
  String get moodTough => 'difficile';

  @override
  String get whatsUp => 'Quoi de neuf ?';

  @override
  String get tellMeMore => 'Je t’écoute. Raconte-moi en plus.';

  @override
  String get moodGreatResponse =>
      'Génial ! Qu’est-ce qui rend ta journée si formidable ?';

  @override
  String get moodGoodResponse =>
      'Chouette ! Quelles bonnes choses se sont passées aujourd’hui ?';

  @override
  String get moodOkayResponse =>
      'D’accord. Tu veux parler de ce qui te préoccupe ?';

  @override
  String get moodLowResponse =>
      'Je suis désolé que tu te sentes comme ça. Que s’est-il passé ?';

  @override
  String get moodToughResponse =>
      'Ça a l’air difficile. Je suis là pour toi. Tu veux en parler ?';

  @override
  String get moodDefaultResponse =>
      'Merci de partager. Raconte-moi plus sur ta journée.';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get newEntry => 'Nouvelle entrée';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get noEntries => 'Aucune entrée';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '1 entrée',
      zero: 'Aucune entrée',
    );
    return '$_temp0';
  }
}
