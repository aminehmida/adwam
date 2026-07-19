import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Dhikr _surahDhikr(String id) => Dhikr(
      id: id,
      arabic: 'سورة $id',
      body: 'آية أولى ۝١ آية ثانية ۝٢',
      repetitions: 1,
      form: DhikrForm.surah,
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

/// Boots the app with a surah-form dhikr plus a small one and opens the
/// morning session.
Future<void> openMorningWithSurah(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final repo = ContentRepository([_dhikr('small'), _surahDhikr('big')]);
  await tester.pumpWidget(DhikrApp(repo: repo, store: await PrefsStore.open()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Morning adhkar'));
  await tester.pumpAndSettle();
}

const _focusHint = 'Tap anywhere to count · swipe to close';

const _volumeChannel = MethodChannel('dev.amine.adwam/volume');

/// Simulates MainActivity reporting a volume-down press over the channel.
Future<void> pressVolumeDown(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _volumeChannel.name,
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('volumeDown'),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

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

  testWidgets(
      'reopened finished dhikr stays open on scroll, collapses on tap, '
      'resets on long-press', (tester) async {
    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openMorning(tester);

    // Finish 'one', then tap 'three' so 'one' stops being active and
    // collapses.
    await tester.longPress(find.text('ذكر one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذكر three'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsNothing);

    // Reopen the finished card: unlike a hidden peek, it survives scrolling.
    await tester.tap(find.text('ذكر one'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 80));
    await tester.pumpAndSettle();

    // A second tap collapses it again (and never counts).
    await tester.tap(find.text('ذكر one'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsNothing);

    // Reopen and long-press: the count resets and the card is live again.
    await tester.tap(find.text('ذكر one'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('ذكر one'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('2 / 2'), findsNothing);
    expect(find.text('0 / 2'), findsOneWidget); // 'one' back to zero
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

  testWidgets('toggling edit mode keeps the list in place', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final repo = ContentRepository([
      for (var i = 1; i <= 20; i++) _dhikr('a${i.toString().padLeft(2, '0')}'),
    ]);
    await tester.pumpWidget(
        DhikrApp(repo: repo, store: await PrefsStore.open()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning adhkar'));
    await tester.pumpAndSettle();

    Set<String> built() => {
          for (var i = 1; i <= 20; i++)
            if (find
                .text('ذكر a${i.toString().padLeft(2, '0')}')
                .evaluate()
                .isNotEmpty)
              'a${i.toString().padLeft(2, '0')}',
        };

    // Scroll deep into the list, away from the top.
    await tester.scrollUntilVisible(find.text('ذكر a20'), 400);
    await tester.pumpAndSettle();
    final beforeEdit = built();
    expect(beforeEdit, isNot(contains('a01')));

    // Entering edit mode stays where the count list was, not at the top.
    // Edit cards are taller, so fewer fit — but the window must overlap.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    final inEdit = built();
    expect(inEdit.intersection(beforeEdit), isNotEmpty);
    expect(inEdit, isNot(contains('a01')));

    // Leaving edit mode stays in place too.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final afterEdit = built();
    expect(afterEdit.intersection(inEdit), isNotEmpty);
    expect(afterEdit, isNot(contains('a01')));
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
    expect(find.text('0 / 3'), findsNWidgets(4)); // other sessions untouched
  });

  testWidgets('volume-down counts like a tap and skips finished dhikrs',
      (tester) async {
    final intercepts = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _volumeChannel,
      (call) async {
        if (call.method == 'setIntercept') {
          intercepts.add(call.arguments as bool);
        }
        return null;
      },
    );
    await openMorning(tester);
    expect(intercepts, [true]); // interception on when the session opens

    await pressVolumeDown(tester);
    expect(find.text('1 / 2'), findsOneWidget); // topmost visible card

    await pressVolumeDown(tester); // completes 'one'
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // 'two' is hidden, so the next press counts 'three'.
    await pressVolumeDown(tester);
    expect(find.text('1 / 2'), findsOneWidget);

    // Edit mode hands the key back to the system; leaving restores it.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(intercepts.last, isFalse);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(intercepts.last, isTrue);
  });

  testWidgets('volume-down counts inside the focus counter', (tester) async {
    await openMorningWithHundred(tester);

    await tester.tap(find.text('ذكر big'));
    await tester.pumpAndSettle();
    expect(find.text(_focusHint), findsOneWidget);
    expect(find.text('1 / 100'), findsNWidgets(2));

    // While the overlay is up, the volume key counts it — not the card the
    // viewport scan would pick.
    await pressVolumeDown(tester);
    expect(find.text('2 / 100'), findsNWidgets(2));
    expect(find.text('0 / 2'), findsOneWidget); // 'small' untouched
  });

  testWidgets('tapping a 100-rep dhikr opens the focus counter and counts',
      (tester) async {
    await openMorningWithHundred(tester);

    await tester.tap(find.text('ذكر big'));
    await tester.pumpAndSettle();
    // The first tap counted and the overlay is up: the counter exists twice,
    // as the card's (hidden) segment and as the overlay's flying copy.
    expect(find.text(_focusHint), findsOneWidget);
    expect(find.text('1 / 100'), findsNWidgets(2));

    // Tapping anywhere on the overlay counts.
    await tester.tap(find.text(_focusHint));
    await tester.pumpAndSettle();
    expect(find.text('2 / 100'), findsNWidgets(2));

    // The small dhikr is untouched and never opens an overlay.
    expect(find.text('0 / 2'), findsOneWidget);
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

  testWidgets('tapping a surah card opens the reader without counting',
      (tester) async {
    await openMorningWithSurah(tester);

    await tester.tap(find.text('سورة big'));
    await tester.pumpAndSettle();
    // The surah body is only rendered inside the reader.
    expect(find.text('آية أولى ۝١ آية ثانية ۝٢'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget); // opening never counts
  });

  testWidgets('volume-down while reading pages the surah, never counting it',
      (tester) async {
    await openMorningWithSurah(tester);

    await tester.tap(find.text('سورة big'));
    await tester.pumpAndSettle();
    expect(find.text('آية أولى ۝١ آية ثانية ۝٢'), findsOneWidget);

    // Volume-down pages the reader instead of counting: the reader stays
    // open and the surah's count is untouched (Done is the only way to count).
    await pressVolumeDown(tester);
    expect(find.text('آية أولى ۝١ آية ثانية ۝٢'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
  });

  testWidgets('the reader\'s Done button completes the surah and closes',
      (tester) async {
    await openMorningWithSurah(tester);

    await tester.tap(find.text('سورة big'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('آية أولى ۝١ آية ثانية ۝٢'), findsNothing);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('back closes the reader without completing the surah',
      (tester) async {
    await openMorningWithSurah(tester);

    await tester.tap(find.text('سورة big'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute(); // system back
    await tester.pumpAndSettle();
    expect(find.text('آية أولى ۝١ آية ثانية ۝٢'), findsNothing);
    expect(find.text('0 / 1'), findsOneWidget); // still on the session, unread
  });
}
