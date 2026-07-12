import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/main.dart';
import 'package:adwam/models/dhikr.dart';

Dhikr _dhikr(String id, {int reps = 2}) => Dhikr(
      id: id,
      arabic: 'ذكر $id',
      repetitions: reps,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: SessionType.values.toSet(),
    );

void main() {
  testWidgets('tap-to-count flow: open session, count to done, badge updates',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ContentRepository([_dhikr('one'), _dhikr('two')]);
    final store = await PrefsStore.open();

    await tester.pumpWidget(DhikrApp(repo: repo, store: store));
    await tester.pumpAndSettle();

    // Home shows 0/2 badges for every context.
    expect(find.text('0 / 2'), findsNWidgets(SessionType.values.length));

    // Open morning session (tests run under the English locale).
    await tester.tap(find.text('Morning adhkar'));
    await tester.pumpAndSettle();

    // Two taps complete the first dhikr (target 2).
    await tester.tap(find.text('ذكر one'));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('ذكر one'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    // Further taps on a done dhikr do nothing.
    await tester.tap(find.text('ذكر one'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    // Back home: morning badge now 1/2.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });
}
