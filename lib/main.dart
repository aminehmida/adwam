import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/content_repository.dart';
import 'data/prefs_store.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'state/list_config_controller.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await ContentRepository.load();
  final store = await PrefsStore.open();
  runApp(DhikrApp(repo: repo, store: store));
}

class DhikrApp extends StatefulWidget {
  final ContentRepository repo;
  final PrefsStore store;

  const DhikrApp({super.key, required this.repo, required this.store});

  @override
  State<DhikrApp> createState() => _DhikrAppState();
}

class _DhikrAppState extends State<DhikrApp> with WidgetsBindingObserver {
  late final ProgressController _progress = ProgressController(widget.store);
  late final ListConfigController _config =
      ListConfigController(widget.store, widget.repo);
  late final SettingsController _settings = SettingsController(widget.store);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _progress.checkDateRollover();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _progress),
        ChangeNotifierProvider.value(value: _config),
        ChangeNotifierProvider.value(value: _settings),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Dhikr',
          locale: settings.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D64)),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D64),
              brightness: Brightness.dark,
            ),
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
