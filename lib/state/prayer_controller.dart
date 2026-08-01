import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../data/prayer_classifier.dart';
import '../data/prayer_offsets.dart';
import '../data/prayer_time_source.dart';
import '../data/prefs_store.dart';
import '../models/daily_progress.dart';
import '../models/dhikr.dart';
import '../models/prayer.dart';
import '../models/prayer_timetable.dart';
import 'progress_controller.dart';

/// Resolves the device's IANA timezone id, or null if it can't be had.
typedef ZoneResolver = Future<String?> Function();

/// The device's own zone, via the platform. Falls back to null rather than
/// throwing: an unresolvable zone must degrade to "we don't know which prayer
/// this is", never to a wrong guess.
Future<String?> deviceZone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null;
  }
}

/// Which prayer the post-prayer adhkar are currently for.
///
/// The app guesses from the device timezone (no location permission — see
/// ZoneDirectory) and the user can override the guess from the session screen.
/// An explicit pick lives in [DailyProgress] so it expires with the session,
/// which means the next prayer starts from a fresh guess without any extra
/// bookkeeping here.
class PrayerController extends ChangeNotifier {
  static const _session = SessionType.postPrayer;

  final ProgressController _progress;
  final PrayerTimeSource _source;
  final PrefsStore _store;
  final DateTime Function() _now;
  final ZoneResolver _resolveZone;

  String? _deviceZoneId;
  String? _overrideZoneId;
  late PrayerOffsets _offsets;

  /// What the app has learned about when this user actually prays, exposed for
  /// tests and diagnostics.
  PrayerOffsets get offsets => _offsets;

  PrayerTimetable? _timetable;
  String? _timetableKey;

  PrayerController(
    this._progress,
    this._source,
    this._store, {
    DateTime Function()? clock,
    ZoneResolver? resolveZone,
  })  : _now = clock ?? DateTime.now,
        _resolveZone = resolveZone ?? deviceZone {
    _overrideZoneId = _store.loadZoneOverride();
    _offsets = _store.loadPrayerOffsets();
    _lastState = _state;
    _progress.addListener(_onProgressChanged);
  }

  /// Last state handed to listeners, so a progress change that doesn't move
  /// the prayer stays quiet. Includes whether it's still a guess: confirming
  /// the prayer the app already guessed leaves [active] alone but must still
  /// redraw the selector's underline from dashed to solid.
  ({DailyPrayer? prayer, bool isGuess})? _lastState;

  ({DailyPrayer? prayer, bool isGuess}) get _state =>
      (prayer: active, isGuess: isGuess);

  /// Every zone the override can choose from.
  List<String> get availableZones => _source.zones.ids;

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  /// Progress notifies on every single tap. Passing that straight on would
  /// make ListConfigController — which the whole session screen watches —
  /// rebuild and re-sort the list once per count, so only speak up when the
  /// prayer in force has actually moved (a selection, or the session expiring).
  void _onProgressChanged() {
    final current = _state;
    if (current == _lastState) return;
    _lastState = current;
    notifyListeners();
  }

  /// Resolves the device zone. Until this completes (or if it fails) the
  /// feature is simply inactive.
  Future<void> init() async {
    final zone = await _resolveZone();
    if (zone == _deviceZoneId) return;
    _deviceZoneId = zone;
    _timetableKey = null;
    notifyListeners();
  }

  String? get zoneId => _overrideZoneId ?? _deviceZoneId;

  /// The zone the user forced in settings, or null when following the device.
  String? get zoneOverride => _overrideZoneId;

  void setZoneOverride(String? zoneId) {
    if (_overrideZoneId == zoneId) return;
    _overrideZoneId = zoneId;
    _timetableKey = null;
    _store.saveZoneOverride(zoneId);
    notifyListeners();
  }

  /// Whether the app can say anything at all about the current prayer. False
  /// when the zone is unknown or the astronomy didn't resolve — the list then
  /// shows every dhikr rather than hiding some on a bad guess.
  bool get isAvailable => _guess != null;

  /// The prayer in force: the user's explicit pick, else the guess, else null.
  DailyPrayer? get active =>
      prayerFromName(_progress.sessionPrayer(_session)) ?? _guess?.prayer;

  /// True while [active] is the app's own guess rather than a user's choice.
  bool get isGuess => _progress.sessionPrayer(_session) == null;

  /// True when the guess is a confident one — the prayer came in recently.
  /// Meaningless once the user has picked; see [isGuess].
  bool get isConfident => _guess?.confident ?? false;

  /// Records the user's own choice, and learns from it. The notification comes
  /// back through [_onProgressChanged], so there is no second one to fire here.
  void select(DailyPrayer prayer) {
    _learn(prayer, manual: true);
    _progress.selectPrayer(_session, prayer.name);
  }

  /// Called when the user finishes the post-prayer session, to reinforce a
  /// guess that went uncorrected. Weighted far below an explicit correction.
  void recordCompletion() {
    final prayer = active;
    if (prayer == null) return;
    _learn(prayer, manual: false);
  }

  void _learn(DailyPrayer prayer, {required bool manual}) {
    final zone = zoneId;
    final table = _currentTimetable();
    if (zone == null || table == null) return;
    final updated = _offsets.observe(
      zoneId: zone,
      prayer: prayer,
      observed: _now(),
      computed: table[prayer],
      manual: manual,
    );
    if (identical(updated, _offsets)) return;
    _offsets = updated;
    _store.savePrayerOffsets(updated);
  }

  PrayerGuess? get _guess {
    final table = _currentTimetable();
    if (table == null) return null;
    return classifyPrayer(
      timetable: table,
      now: _now(),
      offsets: _offsets.byPrayer,
      lastConfirmedToday: prayerFromName(_progress.confirmedPrayer),
    );
  }

  /// Timetables are per zone per local day, so cache on that key — the guess
  /// is read on every rebuild of the session list.
  PrayerTimetable? _currentTimetable() {
    final zone = zoneId;
    if (zone == null) return null;
    final now = _now();
    final key = '$zone@${dateStampOf(now)}';
    if (key != _timetableKey) {
      _timetable = _source.timetableFor(zoneId: zone, localDay: now);
      _timetableKey = key;
    }
    return _timetable;
  }
}
