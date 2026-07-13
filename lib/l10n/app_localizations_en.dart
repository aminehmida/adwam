// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Adwam';

  @override
  String get sessionMorning => 'Morning adhkar';

  @override
  String get sessionEvening => 'Evening adhkar';

  @override
  String get sessionPostPrayer => 'After-prayer adhkar';

  @override
  String get sessionSleep => 'Bedtime adhkar';

  @override
  String get editList => 'Edit list';

  @override
  String get doneEditing => 'Done';

  @override
  String get virtue => 'Virtue';

  @override
  String get translation => 'Translation';

  @override
  String get tierProtection => 'Protection';

  @override
  String get tierReward => 'Reward';

  @override
  String get tierOther => 'Other benefits';

  @override
  String get tierHighRep => 'High repetitions';

  @override
  String get fullSurahs => 'Full surahs';

  @override
  String get resetOrderTitle => 'Reset to default order?';

  @override
  String get resetOrderBody =>
      'This list will be reordered and all adhkar shown again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get reset => 'Reset';

  @override
  String get myDuas => 'My duas';

  @override
  String get addCustomDua => 'Add dua';

  @override
  String get customDuaNewTitle => 'New dua';

  @override
  String get customDuaEditTitle => 'Edit dua';

  @override
  String get customDuaTextHint => 'Dua text';

  @override
  String get customDuaSessions => 'Show in';

  @override
  String get save => 'Save';

  @override
  String get customDuaDeleteTitle => 'Delete this dua?';

  @override
  String get customDuaDeleteBody =>
      'It will be removed from every session it appears in.';

  @override
  String get delete => 'Delete';

  @override
  String get editCustomDua => 'Edit';

  @override
  String get deleteCustomDua => 'Delete';

  @override
  String get resetSessionTitle => 'Reset progress?';

  @override
  String resetSessionBody(String session) {
    return 'Long pressing $session resets today\'s progress for everything inside. Are you sure?';
  }

  @override
  String get dontShowAgain => 'Don\'t show this again';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get volumeKeyCounting => 'Count with volume button';

  @override
  String get volumeKeyCountingBody =>
      'Pressing volume down counts the current dhikr; the volume itself won\'t change while counting.';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get showTranslationBody =>
      'English meaning inside each dhikr\'s Translation section.';

  @override
  String get showTransliteration => 'Show transliteration';

  @override
  String get showTransliterationBody =>
      'Latin-letter pronunciation guide inside the Translation section.';

  @override
  String get resetTodayProgress => 'Reset today\'s progress';

  @override
  String get resetTodayBody => 'All of today\'s counters will start over.';

  @override
  String get resetCustomizations => 'Reset all customizations';

  @override
  String get resetCustomizationsBody =>
      'Order and hidden adhkar in every list will return to the defaults.';

  @override
  String get about => 'About';

  @override
  String get aboutBody =>
      'Daily adhkar. Sources: Hisn al-Muslim (hisnmuslim.com), the Seen-Arabic Morning & Evening Adhkar database, and the Quran text from Tanzil (tanzil.net).';

  @override
  String get tapAnywhereToCount => 'Tap anywhere to count · swipe to close';

  @override
  String get doneReading => 'Done';

  @override
  String get quranFontSize => 'Quran font size';

  @override
  String get quranFontSizeBody => 'Text size when reading a full surah.';
}
