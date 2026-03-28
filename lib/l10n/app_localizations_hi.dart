// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'DearDays';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get account => 'खाता';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get subscription => 'सदस्यता';

  @override
  String get manage => 'प्रबंधित करें';

  @override
  String get journaling => 'डायरी';

  @override
  String get dailyReminder => 'दैनिक रिमाइंडर';

  @override
  String dailyReminderSet(String time) {
    return 'दैनिक रिमाइंडर $time पर सेट किया गया';
  }

  @override
  String get writingStyle => 'लेखन शैली';

  @override
  String writingStyleUpdated(String style) {
    return 'लेखन शैली $style में अपडेट की गई';
  }

  @override
  String get writingStyleFailed => 'लेखन शैली अपडेट करने में विफल।';

  @override
  String get memoir => 'संस्मरण';

  @override
  String get memoirDesc => 'तीसरे व्यक्ति में कथा, चिंतनशील लहजा';

  @override
  String get diary => 'डायरी';

  @override
  String get diaryDesc => 'पहले व्यक्ति में, अनौपचारिक दैनिक प्रविष्टियाँ';

  @override
  String get story => 'कहानी';

  @override
  String get storyDesc => 'सिनेमाई कथाकथन, जीवंत दृश्य';

  @override
  String get chapterOrganization => 'अध्याय व्यवस्था';

  @override
  String get appearance => 'दिखावट';

  @override
  String get language => 'भाषा';

  @override
  String get appLanguage => 'ऐप भाषा';

  @override
  String get systemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get privacySecurity => 'गोपनीयता और सुरक्षा';

  @override
  String get biometricLock => 'बायोमेट्रिक लॉक';

  @override
  String get verifyBiometric =>
      'बायोमेट्रिक लॉक सक्षम करने के लिए अपनी पहचान सत्यापित करें';

  @override
  String get pinLock => 'पिन लॉक';

  @override
  String get patternLock => 'पैटर्न लॉक';

  @override
  String get active => 'सक्रिय';

  @override
  String get setUp => 'सेट करें';

  @override
  String get encryptionInfo => 'एन्क्रिप्शन जानकारी';

  @override
  String get zeroKnowledgeEncryption => 'ज़ीरो-नॉलेज एन्क्रिप्शन';

  @override
  String get algorithm => 'एल्गोरिदम';

  @override
  String get keyDerivation => 'की डेरिवेशन';

  @override
  String get salt => 'सॉल्ट';

  @override
  String get uniqueSalt => 'प्रति उपयोगकर्ता 256-बिट अद्वितीय';

  @override
  String get encryptionExplanation =>
      'आपकी एन्क्रिप्शन की आपके पासवर्ड से बनाई गई है और कभी आपके डिवाइस से बाहर नहीं जाती। सर्वर केवल एन्क्रिप्टेड डेटा स्टोर करता है — हम आपकी डायरी नहीं पढ़ सकते।';

  @override
  String get gotIt => 'समझ गया';

  @override
  String get data => 'डेटा';

  @override
  String get exportAllData => 'सभी डेटा एक्सपोर्ट करें';

  @override
  String get exportYourData => 'अपना डेटा एक्सपोर्ट करें';

  @override
  String get exportingData => 'डेटा एक्सपोर्ट हो रहा है...';

  @override
  String exportFailed(String error) {
    return 'एक्सपोर्ट विफल: $error';
  }

  @override
  String get json => 'JSON';

  @override
  String get jsonDesc => 'मशीन-पठनीय, सभी फ़ील्ड शामिल';

  @override
  String get pdf => 'PDF';

  @override
  String get pdfDesc => 'प्रिंट-तैयार पुस्तक प्रारूप';

  @override
  String get deleteAccount => 'खाता हटाएं';

  @override
  String get deleteAccountTitle => 'खाता हटाएं?';

  @override
  String get deleteAccountWarning =>
      'यह आपका खाता और सभी डायरी प्रविष्टियाँ स्थायी रूप से हटा देगा। यह क्रिया वापस नहीं की जा सकती।\n\nआपका एन्क्रिप्टेड डेटा सर्वर से मिटा दिया जाएगा।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get deleteEverything => 'सब कुछ हटाएं';

  @override
  String get typeDeleteToConfirm => 'पुष्टि के लिए DELETE टाइप करें';

  @override
  String get confirmDelete => 'हटाने की पुष्टि करें';

  @override
  String get deleteAccountFailed =>
      'खाता हटाने में विफल। कृपया पुनः प्रयास करें।';

  @override
  String get about => 'जानकारी';

  @override
  String get version => 'संस्करण';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get termsOfService => 'सेवा की शर्तें';

  @override
  String get goodMorning => 'सुप्रभात';

  @override
  String get goodAfternoon => 'नमस्ते';

  @override
  String get goodEvening => 'शुभ संध्या';

  @override
  String get morning => 'सुबह';

  @override
  String get afternoon => 'दोपहर';

  @override
  String get evening => 'शाम';

  @override
  String get dailyLimitReached =>
      'आपने आज की मेमोरी सीमा पूरी कर ली है। कल वापस आएं!';

  @override
  String get moodGreat => 'बहुत अच्छा';

  @override
  String get moodGood => 'अच्छा';

  @override
  String get moodOkay => 'ठीक';

  @override
  String get moodLow => 'उदास';

  @override
  String get moodTough => 'कठिन';

  @override
  String get whatsUp => 'क्या हाल है?';

  @override
  String get tellMeMore => 'मैं सुन रहा हूँ। मुझे और बताओ।';

  @override
  String get moodGreatResponse =>
      'यह तो कमाल है! आपका दिन इतना अच्छा क्यों है?';

  @override
  String get moodGoodResponse => 'अच्छा है! आज क्या अच्छा हुआ?';

  @override
  String get moodOkayResponse =>
      'ठीक है। बताना चाहोगे क्या दिमाग में चल रहा है?';

  @override
  String get moodLowResponse =>
      'मुझे दुख है कि आप ऐसा महसूस कर रहे हैं। क्या हुआ?';

  @override
  String get moodToughResponse =>
      'यह मुश्किल लगता है। मैं आपके साथ हूँ। बताना चाहोगे क्या हो रहा है?';

  @override
  String get moodDefaultResponse =>
      'शेयर करने के लिए धन्यवाद। अपने दिन के बारे में और बताओ।';

  @override
  String get save => 'सेव करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get newEntry => 'नई प्रविष्टि';

  @override
  String get today => 'आज';

  @override
  String get yesterday => 'कल';

  @override
  String daysAgo(int count) {
    return '$count दिन पहले';
  }

  @override
  String get weekAgo => '1 सप्ताह पहले';

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count महीने पहले',
      one: '1 महीना पहले',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count साल पहले',
      one: '1 साल पहले',
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
  String get noEntries => 'अभी कोई प्रविष्टि नहीं';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रविष्टियाँ',
      one: '1 प्रविष्टि',
      zero: 'कोई प्रविष्टि नहीं',
    );
    return '$_temp0';
  }
}
