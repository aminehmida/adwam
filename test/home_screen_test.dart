import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/main.dart';
import 'package:adwam/models/daily_progress.dart';
import 'package:adwam/models/dhikr.dart';

Dhikr _dhikr(String id) => Dhikr(
      id: id,
      arabic: 'ذكر $id',
      repetitions: 2,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: SessionType.values.toSet(),
    );

/// Boots the app on the home screen with one morning dhikr already done,
/// so the morning badge reads '1 / 3' and the others '0 / 3'.
Future<void> bootHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'progress': DailyProgress(
      dateStamp: dateStampOf(DateTime.now()),
      counts: const {'morning.one': 2},
      done: const {'morning.one'},
    ).toJsonString(),
  });
  final repo =
      ContentRepository([_dhikr('one'), _dhikr('two'), _dhikr('three')]);
  await tester.pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
  await tester.pumpAndSettle();
}

Future<void> longPressMorning(WidgetTester tester) async {
  await tester.longPress(find.text('Morning adhkar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('long-press shows the reset confirmation dialog', (tester) async {
    await bootHome(tester);
    expect(find.text('1 / 3'), findsOneWidget);

    await longPressMorning(tester);
    expect(find.text('Reset progress?'), findsOneWidget);
    expect(find.text("Don't show this again"), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget); // untouched
  });

  testWidgets('confirming resets only that session', (tester) async {
    await bootHome(tester);

    await longPressMorning(tester);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsNothing);
    expect(find.text('0 / 3'), findsNWidgets(5));
  });

  testWidgets('don\'t-show-again mutes the dialog on later long-presses',
      (tester) async {
    await bootHome(tester);

    await longPressMorning(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 3'), findsNWidgets(5));

    // Next long-press resets straight away, no dialog.
    await longPressMorning(tester);
    expect(find.text('Reset progress?'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('skipSessionResetConfirm'), isTrue);
  });
}
