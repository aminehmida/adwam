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
  String get translation => 'الترجمة';

  @override
  String afterPrayers(String prayers) {
    return 'بعد $prayers';
  }

  @override
  String timesAfterPrayers(int count, String prayers) {
    return '$count مرات بعد $prayers';
  }

  @override
  String get prayerJoiner => ' و';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerDhuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get tierProtection => 'الحماية';

  @override
  String get tierReward => 'الثواب';

  @override
  String get tierOther => 'فضائل أخرى';

  @override
  String get tierHighRep => 'الأذكار المكرَّرة';

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
  String get myDuas => 'أدعيتي';

  @override
  String get addCustomDua => 'إضافة دعاء';

  @override
  String get customDuaNewTitle => 'دعاء جديد';

  @override
  String get customDuaEditTitle => 'تعديل الدعاء';

  @override
  String get customDuaTextHint => 'نص الدعاء';

  @override
  String get customDuaSessions => 'يظهر في';

  @override
  String get save => 'حفظ';

  @override
  String get customDuaDeleteTitle => 'حذف هذا الدعاء؟';

  @override
  String get customDuaDeleteBody => 'سيُزال من كل الجلسات التي يظهر فيها.';

  @override
  String get delete => 'حذف';

  @override
  String get editCustomDua => 'تعديل';

  @override
  String get deleteCustomDua => 'حذف';

  @override
  String get resetSessionTitle => 'تصفير التقدّم؟';

  @override
  String resetSessionBody(String session) {
    return 'الضغط المطوّل على «$session» يصفّر تقدّم اليوم لجميع الأذكار داخلها. هل أنت متأكد؟';
  }

  @override
  String get dontShowAgain => 'عدم إظهار هذه الرسالة مجددًا';

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
  String get theme => 'المظهر';

  @override
  String get themeSystem => 'حسب الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get volumeKeyCounting => 'العدّ بزر الصوت';

  @override
  String get volumeKeyCountingBody =>
      'الضغط على زر خفض الصوت يعدّ الذكر الحالي، ولن يتغيّر مستوى الصوت أثناء العدّ.';

  @override
  String get showTranslation => 'عرض الترجمة';

  @override
  String get showTranslationBody =>
      'عرض معنى الذكر بالإنجليزية داخل قسم الترجمة.';

  @override
  String get showTransliteration => 'عرض النطق بالحروف اللاتينية';

  @override
  String get showTransliterationBody =>
      'دليل نطق الذكر بالحروف اللاتينية داخل قسم الترجمة.';

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
      'أذكار اليوم والليلة. المصادر: حصن المسلم (hisnmuslim.com) وقاعدة بيانات أذكار الصباح والمساء (Seen-Arabic) ونص القرآن من مشروع تنزيل (tanzil.net).';

  @override
  String get tapAnywhereToCount => 'انقر في أي مكان للعدّ · اسحب للإغلاق';

  @override
  String get doneReading => 'تم';

  @override
  String get quranFontSize => 'حجم خط القرآن';

  @override
  String get quranFontSizeBody => 'حجم النص عند قراءة سورة كاملة.';
}
