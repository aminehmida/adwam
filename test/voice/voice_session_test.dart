import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/l10n/app_localizations.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/screens/session_screen.dart';
import 'package:adwam/state/list_config_controller.dart';
import 'package:adwam/state/prayer_controller.dart';
import 'package:adwam/state/progress_controller.dart';
import 'package:adwam/state/settings_controller.dart';
import 'package:adwam/voice/model_catalog.dart';
import 'package:adwam/voice/model_store.dart';
import 'package:adwam/voice/phrase_matcher.dart';
import 'package:adwam/voice/voice_session_controller.dart';

import '../support/prayer_support.dart';

/// A controller that claims to be listening and counts how often it is told to
/// stop. There is no microphone in a widget test, so this is the only
/// observable part of closing one.
class _StoppableVoice extends VoiceSessionController {
  _StoppableVoice()
      : super(modelStore: ModelStore(), spec: fastConformerArabic);

  int stops = 0;

  @override
  bool get isOn => true;

  @override
  Future<void> stop() async => stops++;
}

/// Hearing a dhikr must do exactly what tapping it does. The recogniser runs
/// on another isolate behind native code, so the controller is injected and
/// matches are fed in directly — the screen cannot tell the difference.
void main() {
  Dhikr dhikr(String id, {int repetitions = 3}) => Dhikr(
        id: id,
        arabic: 'ذكر $id',
        repetitions: repetitions,
        form: DhikrForm.short,
        tier: BenefitTier.none,
        contexts: SessionType.values.toSet(),
      );

  late ProgressController progress;
  late VoiceSessionController voice;

  Future<void> openSession(WidgetTester tester, List<Dhikr> dhikrs) async {
    SharedPreferences.setMockInitialValues({});
    final store = await PrefsStore.open();
    final repo = ContentRepository(dhikrs);
    progress = ProgressController(store);
    final prayer = unlocatedPrayerController(store);
    final settings = SettingsController(store);
    final config = ListConfigController(store, repo, settings, prayer);
    voice = VoiceSessionController(
      modelStore: ModelStore(),
      spec: fastConformerArabic,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: progress),
          ChangeNotifierProvider<PrayerController>.value(value: prayer),
          ChangeNotifierProvider.value(value: config),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          home: SessionScreen(session: SessionType.morning, voice: voice),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hearing a dhikr counts it once', (tester) async {
    await openSession(tester, [dhikr('one'), dhikr('two')]);

    voice.emitMatch(const PhraseMatch('one', 0.9));
    await tester.pumpAndSettle();

    expect(progress.countFor(SessionType.morning, 'one'), 1);
    expect(progress.countFor(SessionType.morning, 'two'), 0);
  });

  testWidgets('a run heard in one breath counts every repetition',
      (tester) async {
    await openSession(tester, [dhikr('one'), dhikr('two')]);

    voice.emitMatch(const PhraseMatch('one', 0.9, repetitions: 3));
    await tester.pumpAndSettle();

    expect(progress.countFor(SessionType.morning, 'one'), 3);
    expect(progress.isDone(SessionType.morning, 'one'), isTrue);
  });

  testWidgets('counting never runs past the target', (tester) async {
    await openSession(tester, [dhikr('one', repetitions: 2), dhikr('two')]);

    // Heard five times, but the dhikr only asks for two.
    voice.emitMatch(const PhraseMatch('one', 0.9, repetitions: 5));
    await tester.pumpAndSettle();

    expect(progress.countFor(SessionType.morning, 'one'), 2);
    expect(progress.isDone(SessionType.morning, 'one'), isTrue);
  });

  testWidgets('a dhikr that is not in the session is ignored', (tester) async {
    await openSession(tester, [dhikr('one'), dhikr('two')]);

    voice.emitMatch(const PhraseMatch('elsewhere', 0.9));
    await tester.pumpAndSettle();

    expect(progress.countFor(SessionType.morning, 'one'), 0);
    expect(progress.countFor(SessionType.morning, 'two'), 0);
  });

  group('leaving the app', () {
    /// Reports itself as listening and records being told to stop, which is
    /// all the screen can observe of a microphone in a widget test.
    late _StoppableVoice stoppable;

    Future<void> openListening(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await PrefsStore.open();
      final repo = ContentRepository([dhikr('one')]);
      final prayer = unlocatedPrayerController(store);
      final settings = SettingsController(store);
      stoppable = _StoppableVoice();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ProgressController(store)),
            ChangeNotifierProvider<PrayerController>.value(value: prayer),
            ChangeNotifierProvider.value(
                value: ListConfigController(store, repo, settings, prayer)),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar'), Locale('en')],
            home:
                SessionScreen(session: SessionType.morning, voice: stoppable),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('locking the phone or switching apps closes the microphone',
        (tester) async {
      await openListening(tester);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        stoppable.stops = 0;
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
        expect(stoppable.stops, 1, reason: state.name);
      }
    });

    testWidgets('a notification shade does not close it', (tester) async {
      // `inactive` also fires for the permission dialog voice mode raises.
      await openListening(tester);
      stoppable.stops = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(stoppable.stops, 0);
    });
  });

  testWidgets('the mic control is offered while counting, not while editing',
      (tester) async {
    await openSession(tester, [dhikr('one')]);
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
  });
}
