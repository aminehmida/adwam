import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/main.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/widgets/context_card.dart';
import 'package:adwam/widgets/tier_header.dart';

/// End-to-end journey over the real bundled content (assets/adhkar.json),
/// run on a device or emulator with `flutter test integration_test`.
/// Prefs are mocked so runs never touch the device's real progress.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real content journey: count, persist, restart, language',
      (tester) async {
    // English UI regardless of device locale, empty progress.
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final repo = await ContentRepository.load();
    await tester
        .pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
    await tester.pumpAndSettle();

    // Home: one card per session, each with a real 0/N badge.
    expect(find.byType(ContextCard), findsNWidgets(SessionType.values.length));
    final morning = repo.defaultList(SessionType.morning);
    final total = morning.length;
    expect(find.text('0 / $total'), findsWidgets);

    // Open the morning session (first card) — the protection band and the
    // first dhikr of the real default sort are on screen.
    await tester.tap(find.byType(ContextCard).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SectionBand, 'Protection'), findsOneWidget);
    final first = morning[0];
    expect(find.text(first.arabic), findsOneWidget);

    // Long-press completes the first dhikr in one gesture.
    await tester.longPress(find.text(first.arabic));
    await tester.pumpAndSettle();
    expect(find.text('${first.repetitions} / ${first.repetitions}'),
        findsWidgets);

    // Tap-to-count the second dhikr once.
    final second = morning[1];
    await tester.tap(find.text(second.arabic));
    await tester.pumpAndSettle();
    expect(find.text('1 / ${second.repetitions}'), findsWidgets);

    // Back home: badge reflects what was completed.
    final completed = 1 + (second.repetitions == 1 ? 1 : 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('$completed / $total'), findsOneWidget);

    // "Restart" the app on the same prefs: progress survives.
    await tester
        .pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
    await tester.pumpAndSettle();
    expect(find.text('$completed / $total'), findsOneWidget);

    // Language toggle: Arabic UI, Arabic app title.
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('أدوَم'), findsOneWidget);
    expect(find.text('الحماية'), findsNothing); // band label only in session
    await tester.tap(find.byType(ContextCard).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SectionBand, 'الحماية'), findsOneWidget);
  });
}
