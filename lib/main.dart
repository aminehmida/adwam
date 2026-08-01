import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/content_repository.dart';
import 'data/prayer_time_source.dart';
import 'data/prefs_store.dart';
import 'data/zone_coordinates.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'state/list_config_controller.dart';
import 'state/prayer_controller.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await ContentRepository.load();
  final store = await PrefsStore.open();
  final zones = await ZoneDirectory.load();
  runApp(DhikrApp(repo: repo, store: store, zones: zones));
}

class DhikrApp extends StatefulWidget {
  final ContentRepository repo;
  final PrefsStore store;

  /// Absent in tests that don't exercise the prayer guess: the post-prayer
  /// session then shows every dhikr, exactly as it does when the device's
  /// timezone can't be resolved.
  final ZoneDirectory zones;

  /// Injection seams for tests — the wall clock and the device timezone.
  final DateTime Function()? clock;
  final ZoneResolver? resolveZone;

  const DhikrApp({
    super.key,
    required this.repo,
    required this.store,
    this.zones = const ZoneDirectory({}),
    this.clock,
    this.resolveZone,
  });

  @override
  State<DhikrApp> createState() => _DhikrAppState();
}

class _DhikrAppState extends State<DhikrApp> with WidgetsBindingObserver {
  late final ProgressController _progress = ProgressController(widget.store);
  late final SettingsController _settings = SettingsController(widget.store);
  late final PrayerController _prayer = PrayerController(
    _progress,
    PrayerTimeSource(widget.zones),
    widget.store,
    clock: widget.clock,
    resolveZone: widget.resolveZone,
  );
  late final ListConfigController _config =
      ListConfigController(widget.store, widget.repo, _settings, _prayer);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prayer.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _progress.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _progress),
        ChangeNotifierProvider.value(value: _prayer),
        ChangeNotifierProvider.value(value: _config),
        ChangeNotifierProvider.value(value: _settings),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Adwam',
          locale: settings.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
