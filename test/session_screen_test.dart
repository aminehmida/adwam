import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/main.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/models/user_list_config.dart';

Dhikr _dhikr(String id) => Dhikr(
      id: id,
      arabic: 'ذكر $id',
      repetitions: 2,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: SessionType.values.toSet(),
    );

Dhikr _hundredDhikr(String id) => Dhikr(
      id: id,
      arabic: 'ذكر $id',
      repetitions: 100,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: SessionType.values.toSet(),
    );

/// Boots the app with three dhikrs ('two' hidden for morning) and opens the
/// morning session. Visible cards show a '0 / 2' counter; collapsed ones
/// show only their title.
Future<void> openMorning(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'config.morning':
        const UserListConfig(hidden: {'two'}).toJsonString(),
  });
  final repo =
      ContentRepository([_dhikr('one'), _dhikr('two'), _dhikr('three')]);
  await tester.pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Morning adhkar'));
  await tester.pumpAndSettle();
}

/// Boots the app with a 100-repetition dhikr plus a small one and opens the
/// morning session.
Future<void> openMorningWithHundred(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final repo = ContentRepository([_hundredDhikr('big'), _dhikr('small')]);
  await tester.pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Morning adhkar'));
  await tester.pumpAndSettle();
}

const _focusHint = 'Tap anywhere to count · swipe to close';

void main() {
  testWidgets('hidden dhikr renders as a collapsed title-only row',
      (tester) async {
    await openMorning(tester);

    expect(find.text('0 / 2'), findsNWidgets(2)); // only the visible cards
    expect(find.text('ذكر two'), findsOneWidget); // title row still there
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('peek on tap, collapse again on second tap', (tester) async {
    await openMorning(tester);

    await tester.tap(find.text('ذكر two'));
    // Let the AnimatedSize expansion finish: mid-animation the expanding
    // card still overlaps its neighbour, so a tap there would hit the
    // wrong card.
    await tester.pumpAndSettle();
    expect(find.text('0 / 2'), findsNWidgets(3)); // full card while peeking

    // Peeking never counts.
    await tester.tap(find.text('ذكر two'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 2'), findsNWidgets(2));
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('peek collapses on scroll', (tester) async {
    // Shrink the viewport so the three cards overflow it — a drag only
    // starts a real scroll when the list has scroll extent.
    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openMorning(tester);

    await tester.tap(find.text('ذكر two'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 2'), findsNWidgets(3));

    // The count list is a CustomScrollView (split around the anchor card).
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  testWidgets('long-press marks a dhikr done without counting each tap',
      (tester) async {
    await openMorning(tester);

    await tester.longPress(find.text('ذكر one'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('back button exits edit mode instead of leaving the screen',
      (tester) async {
    await openMorning(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));

    await tester.pageBack();
    await tester.pumpAndSettle();
    // Still on the session screen, edit controls gone.
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.tune), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Morning adhkar'), findsOneWidget); // back home
  });

  testWidgets('hiding a card in edit mode removes it from the home badge',
      (tester) async {
    await openMorning(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.visibility).first);
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.check)); // leave edit mode
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('0 / 1'), findsOneWidget); // morning: 1 visible left
    expect(find.text('0 / 3'), findsNWidgets(3)); // other sessions untouched
  });

  testWidgets('tapping a 100-rep dhikr opens the focus counter and counts',
      (tester) async {
    await openMorningWithHundred(tester);

    await tester.tap(find.text('ذكر big'));
    await tester.pumpAndSettle();
    // The first tap counted and the overlay shows the big counter.
    expect(find.text(_focusHint), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Tapping anywhere on the overlay counts.
    await tester.tap(find.text(_focusHint));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    // The small dhikr never opens the overlay.
    expect(find.text('/ 2'), findsNothing);
  });

  testWidgets('swiping dismisses the focus counter without counting',
      (tester) async {
    await openMorningWithHundred(tester);

    await tester.tap(find.text('ذكر big'));
    await tester.pumpAndSettle();
    expect(find.text(_focusHint), findsOneWidget);

    await tester.drag(find.text(_focusHint), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text(_focusHint), findsNothing);
    expect(find.text('1 / 100'), findsOneWidget); // only the first tap counted
  });

  testWidgets('back dismisses the focus counter without leaving the screen',
      (tester) async {
    await openMorningWithHundred(tester);

    await tester.tap(find.text('ذكر big'));
    await tester.pumpAndSettle();
    expect(find.text(_focusHint), findsOneWidget);

    await tester.binding.handlePopRoute(); // system back
    await tester.pumpAndSettle();
    expect(find.text(_focusHint), findsNothing);
    expect(find.text('1 / 100'), findsOneWidget); // still on the session
  });

  testWidgets('reaching the target closes the focus counter and marks done',
      (tester) async {
    await openMorningWithHundred(tester);

    await tester.tap(find.text('ذكر big'));
    await tester.pumpAndSettle();
    for (var i = 2; i <= 100; i++) {
      await tester.tap(find.text(_focusHint), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(find.text(_focusHint), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
