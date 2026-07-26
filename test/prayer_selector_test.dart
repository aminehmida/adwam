import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/data/zone_coordinates.dart';
import 'package:adwam/main.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/widgets/prayer_selector.dart';

import 'support/prayer_support.dart';

/// Post-prayer content with the same shape as the real thing: adhkar said
/// after every prayer, plus ones tagged for specific prayers.
Dhikr _dhikr(String id, {List<String> prayers = const []}) => Dhikr(
      id: id,
      arabic: 'ذكر $id',
      repetitions: 2,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: {SessionType.postPrayer},
      prayers: prayers,
    );

final _repo = ContentRepository([
  _dhikr('always'),
  _dhikr('fajrmaghrib', prayers: ['fajr', 'maghrib']),
  _dhikr('fajronly', prayers: ['fajr']),
]);

/// Boots the app with a resolvable location, so the prayer feature is active.
/// Which prayer is *guessed* depends on the runner's timezone, so no test
/// asserts the initial guess — they select explicitly instead.
Future<void> _pumpApp(
  WidgetTester tester, {
  ZoneDirectory zones = testZones,
  String? zone = 'Africa/Tunis',
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await PrefsStore.open();
  await tester.pumpWidget(DhikrApp(
    repo: _repo,
    store: store,
    zones: zones,
    clock: () => DateTime(2026, 3, 15, 13, 0),
    resolveZone: () async => zone,
  ));
  await tester.pumpAndSettle();
}

Future<void> _openPostPrayer(WidgetTester tester) async {
  await tester.tap(find.text('After-prayer adhkar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the selector offers all five prayers', (tester) async {
    await _pumpApp(tester);
    await _openPostPrayer(tester);

    expect(find.byType(PrayerSelector), findsOneWidget);
    for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('picking a prayer hides the adhkar that do not belong to it',
      (tester) async {
    await _pumpApp(tester);
    await _openPostPrayer(tester);

    await tester.tap(find.text('Asr'));
    await tester.pumpAndSettle();
    expect(find.text('ذكر always'), findsOneWidget);
    expect(find.text('ذكر fajrmaghrib'), findsNothing);
    expect(find.text('ذكر fajronly'), findsNothing);

    await tester.tap(find.text('Maghrib'));
    await tester.pumpAndSettle();
    expect(find.text('ذكر always'), findsOneWidget);
    expect(find.text('ذكر fajrmaghrib'), findsOneWidget);
    expect(find.text('ذكر fajronly'), findsNothing);

    await tester.tap(find.text('Fajr'));
    await tester.pumpAndSettle();
    expect(find.text('ذكر fajrmaghrib'), findsOneWidget);
    expect(find.text('ذكر fajronly'), findsOneWidget);
  });

  testWidgets('counts survive switching prayer', (tester) async {
    await _pumpApp(tester);
    await _openPostPrayer(tester);

    await tester.tap(find.text('Fajr'));
    await tester.pumpAndSettle();

    // One of two taps on a shared dhikr.
    await tester.tap(find.text('ذكر always'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    // Correcting a wrong guess must never cost the user their progress.
    await tester.tap(find.text('Isha'));
    await tester.pumpAndSettle();
    expect(find.text('ذكر always'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('edit mode shows every dhikr and hides the selector',
      (tester) async {
    await _pumpApp(tester);
    await _openPostPrayer(tester);

    await tester.tap(find.text('Asr'));
    await tester.pumpAndSettle();
    expect(find.text('ذكر fajronly'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // Otherwise a filtered-out dhikr could be neither reordered nor unhidden.
    expect(find.text('ذكر always'), findsOneWidget);
    expect(find.text('ذكر fajrmaghrib'), findsOneWidget);
    expect(find.text('ذكر fajronly'), findsOneWidget);
    expect(find.byType(PrayerSelector), findsNothing);
  });

  testWidgets('the guess is announced as a guess until the user picks',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester);
    await _openPostPrayer(tester);

    // Exactly one tab is selected, and it is flagged as guessed.
    expect(find.bySemanticsLabel(RegExp(r', guessed$')), findsOneWidget);

    await tester.tap(find.text('Dhuhr'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r', guessed$')), findsNothing);
    handle.dispose();
  });

  testWidgets('confirming the prayer the app already guessed clears the marker',
      (tester) async {
    // The selection doesn't change `active` here, only whether it's a guess.
    // Easy to miss when deciding what counts as a change worth redrawing.
    final handle = tester.ensureSemantics();
    await _pumpApp(tester);
    await _openPostPrayer(tester);

    final guessed = find.bySemanticsLabel(RegExp(r', guessed$'));
    expect(guessed, findsOneWidget);
    await tester.tap(guessed);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r', guessed$')), findsNothing);
    handle.dispose();
  });

  testWidgets('the home card names the prayer', (tester) async {
    await _pumpApp(tester);
    await _openPostPrayer(tester);
    await tester.tap(find.text('Isha'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Isha'), findsOneWidget);
  });

  testWidgets('an unresolvable timezone shows every dhikr and no selector',
      (tester) async {
    await _pumpApp(tester, zone: null);
    await _openPostPrayer(tester);

    // Degrading to "show everything" is the safe direction: hiding adhkar
    // because a lookup failed would be worse than showing a few extra.
    expect(find.byType(PrayerSelector), findsNothing);
    expect(find.text('ذكر always'), findsOneWidget);
    expect(find.text('ذكر fajrmaghrib'), findsOneWidget);
    expect(find.text('ذكر fajronly'), findsOneWidget);
  });

  testWidgets('an unknown zone id degrades the same way', (tester) async {
    await _pumpApp(tester, zone: 'Mars/Olympus');
    await _openPostPrayer(tester);

    expect(find.byType(PrayerSelector), findsNothing);
    expect(find.text('ذكر fajronly'), findsOneWidget);
  });

  testWidgets('other sessions have no prayer selector', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await PrefsStore.open();
    final repo = ContentRepository([
      Dhikr(
        id: 'm1',
        arabic: 'ذكر صباح',
        repetitions: 1,
        form: DhikrForm.short,
        tier: BenefitTier.none,
        contexts: {SessionType.morning},
      ),
    ]);
    await tester.pumpWidget(DhikrApp(
      repo: repo,
      store: store,
      zones: testZones,
      clock: () => DateTime(2026, 3, 15, 13, 0),
      resolveZone: () async => 'Africa/Tunis',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning adhkar'));
    await tester.pumpAndSettle();
    expect(find.byType(PrayerSelector), findsNothing);
  });
}
