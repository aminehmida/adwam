// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'أدوَم';

  @override
  String get sessionMorning => 'أذكار الصباح';

  @override
  String get sessionEvening => 'أذكار المساء';

  @override
  String get sessionPostPrayer => 'أذكار بعد الصلاة';

  @override
  String get sessionSleep => 'أذكار النوم';

  @override
  String get editList => 'تعديل القائمة';

  @override
  String get doneEditing => 'تم';

  @override
  String get virtue => 'الفضل';

  @override
  String get tierProtection => 'الحماية';

  @override
  String get tierReward => 'الثواب';

  @override
  String get tierOther => 'فضائل أخرى';

  @override
  String get fullSurahs => 'سور كاملة';

  @override
  String get resetOrderTitle => 'استعادة الترتيب الافتراضي؟';

  @override
  String get resetOrderBody => 'سيُعاد ترتيب هذه القائمة وإظهار جميع الأذكار.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get reset => 'استعادة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'لغة الجهاز';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get resetTodayProgress => 'تصفير عدّادات اليوم';

  @override
  String get resetTodayBody => 'ستبدأ جميع عدّادات اليوم من جديد.';

  @override
  String get resetCustomizations => 'استعادة جميع التخصيصات';

  @override
  String get resetCustomizationsBody =>
      'سيعود ترتيب القوائم والأذكار المخفية إلى الوضع الافتراضي.';

  @override
  String get about => 'حول التطبيق';

  @override
  String get aboutBody =>
      'أذكار اليوم والليلة. المصادر: حصن المسلم (hisnmuslim.com) وقاعدة بيانات أذكار الصباح والمساء (Seen-Arabic).';
}
