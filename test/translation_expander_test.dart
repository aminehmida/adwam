import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/main.dart';
import 'package:adwam/models/dhikr.dart';

final _dhikr = Dhikr(
  id: 'one',
  arabic: 'ذكر واحد',
  repetitions: 2,
  form: DhikrForm.short,
  tier: BenefitTier.none,
  translation: 'One dhikr meaning',
  transliteration: 'Dhikrun wahid',
  contexts: SessionType.values.toSet(),
);

/// Boots the app with the given prefs and opens the morning session,
/// tapping its title in whichever language the UI renders.
Future<void> openMorning(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String sessionTitle = 'Morning adhkar',
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final repo = ContentRepository([_dhikr]);
  await tester.pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sessionTitle));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('English UI: Translation expander reveals both texts on tap',
      (tester) async {
    await openMorning(tester);

    expect(find.text('Translation'), findsOneWidget);
    expect(find.text('Dhikrun wahid'), findsNothing);
    expect(find.text('One dhikr meaning'), findsNothing);

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();

    expect(find.text('Dhikrun wahid'), findsOneWidget);
    expect(find.text('One dhikr meaning'), findsOneWidget);
  });

  testWidgets('both toggles off hides the expander entirely', (tester) async {
    await openMorning(
      tester,
      prefs: {'showTranslation': false, 'showTransliteration': false},
    );

    expect(find.text('Translation'), findsNothing);
  });

  testWidgets('Arabic UI never shows the expander', (tester) async {
    await openMorning(
      tester,
      prefs: {'locale': 'ar'},
      sessionTitle: 'أذكار الصباح',
    );

    expect(find.text('الترجمة'), findsNothing);
  });
}
