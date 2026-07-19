import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Adwam'**
  String get appTitle;

  /// No description provided for @sessionMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning adhkar'**
  String get sessionMorning;

  /// No description provided for @sessionEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening adhkar'**
  String get sessionEvening;

  /// No description provided for @sessionPostPrayer.
  ///
  /// In en, this message translates to:
  /// **'After-prayer adhkar'**
  String get sessionPostPrayer;

  /// No description provided for @sessionSleep.
  ///
  /// In en, this message translates to:
  /// **'Bedtime adhkar'**
  String get sessionSleep;

  /// No description provided for @sessionWaking.
  ///
  /// In en, this message translates to:
  /// **'Wake-up adhkar'**
  String get sessionWaking;

  /// No description provided for @editList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get editList;

  /// No description provided for @doneEditing.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneEditing;

  /// No description provided for @virtue.
  ///
  /// In en, this message translates to:
  /// **'Virtue'**
  String get virtue;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @afterPrayers.
  ///
  /// In en, this message translates to:
  /// **'After {prayers}'**
  String afterPrayers(String prayers);

  /// No description provided for @timesAfterPrayers.
  ///
  /// In en, this message translates to:
  /// **'{count}× after {prayers}'**
  String timesAfterPrayers(int count, String prayers);

  /// No description provided for @prayerJoiner.
  ///
  /// In en, this message translates to:
  /// **' & '**
  String get prayerJoiner;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @tierProtection.
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get tierProtection;

  /// No description provided for @tierReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get tierReward;

  /// No description provided for @tierOther.
  ///
  /// In en, this message translates to:
  /// **'Other benefits'**
  String get tierOther;

  /// No description provided for @tierHighRep.
  ///
  /// In en, this message translates to:
  /// **'High repetitions'**
  String get tierHighRep;

  /// No description provided for @fullSurahs.
  ///
  /// In en, this message translates to:
  /// **'Full surahs'**
  String get fullSurahs;

  /// No description provided for @resetOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to default order?'**
  String get resetOrderTitle;

  /// No description provided for @resetOrderBody.
  ///
  /// In en, this message translates to:
  /// **'This list will be reordered and all adhkar shown again.'**
  String get resetOrderBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @myDuas.
  ///
  /// In en, this message translates to:
  /// **'My duas'**
  String get myDuas;

  /// No description provided for @addCustomDua.
  ///
  /// In en, this message translates to:
  /// **'Add dua'**
  String get addCustomDua;

  /// No description provided for @customDuaNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New dua'**
  String get customDuaNewTitle;

  /// No description provided for @customDuaEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit dua'**
  String get customDuaEditTitle;

  /// No description provided for @customDuaTextHint.
  ///
  /// In en, this message translates to:
  /// **'Dua text'**
  String get customDuaTextHint;

  /// No description provided for @customDuaSessions.
  ///
  /// In en, this message translates to:
  /// **'Show in'**
  String get customDuaSessions;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @customDuaDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this dua?'**
  String get customDuaDeleteTitle;

  /// No description provided for @customDuaDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from every session it appears in.'**
  String get customDuaDeleteBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editCustomDua.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editCustomDua;

  /// No description provided for @deleteCustomDua.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteCustomDua;

  /// No description provided for @resetSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset progress?'**
  String get resetSessionTitle;

  /// No description provided for @resetSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Long pressing {session} resets today\'s progress for everything inside. Are you sure?'**
  String resetSessionBody(String session);

  /// No description provided for @dontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get dontShowAgain;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @volumeKeyCounting.
  ///
  /// In en, this message translates to:
  /// **'Count with volume button'**
  String get volumeKeyCounting;

  /// No description provided for @volumeKeyCountingBody.
  ///
  /// In en, this message translates to:
  /// **'Pressing volume down counts the current dhikr, or scrolls the page while reading a surah; the volume itself won\'t change.'**
  String get volumeKeyCountingBody;

  /// No description provided for @showTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get showTranslation;

  /// No description provided for @showTranslationBody.
  ///
  /// In en, this message translates to:
  /// **'English meaning inside each dhikr\'s Translation section.'**
  String get showTranslationBody;

  /// No description provided for @showTransliteration.
  ///
  /// In en, this message translates to:
  /// **'Show transliteration'**
  String get showTransliteration;

  /// No description provided for @showTransliterationBody.
  ///
  /// In en, this message translates to:
  /// **'Latin-letter pronunciation guide inside the Translation section.'**
  String get showTransliterationBody;

  /// No description provided for @resetTodayProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset today\'s progress'**
  String get resetTodayProgress;

  /// No description provided for @resetTodayBody.
  ///
  /// In en, this message translates to:
  /// **'All of today\'s counters will start over.'**
  String get resetTodayBody;

  /// No description provided for @resetCustomizations.
  ///
  /// In en, this message translates to:
  /// **'Reset all customizations'**
  String get resetCustomizations;

  /// No description provided for @resetCustomizationsBody.
  ///
  /// In en, this message translates to:
  /// **'Order and hidden adhkar in every list will return to the defaults.'**
  String get resetCustomizationsBody;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Daily adhkar. Sources: Hisn al-Muslim (hisnmuslim.com), the Seen-Arabic Morning & Evening Adhkar database, and the Quran text from Tanzil (tanzil.net).'**
  String get aboutBody;

  /// No description provided for @tapAnywhereToCount.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to count · swipe to close'**
  String get tapAnywhereToCount;

  /// No description provided for @doneReading.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneReading;

  /// No description provided for @quranFontSize.
  ///
  /// In en, this message translates to:
  /// **'Quran font size'**
  String get quranFontSize;

  /// No description provided for @quranFontSizeBody.
  ///
  /// In en, this message translates to:
  /// **'Text size when reading a full surah.'**
  String get quranFontSizeBody;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
