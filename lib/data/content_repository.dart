import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dhikr.dart';

/// Quran passages pin to the top of a session, then the tiered dhikrs, then
/// the high-repetition counting dhikrs, and full surahs stay at the very
/// bottom (the last thing read, e.g. Surah al-Mulk before sleep).
int _band(Dhikr d) {
  if (d.isHighRep) return 2;
  return switch (d.form) {
    DhikrForm.quran => 0,
    DhikrForm.surah => 3,
    _ => 1,
  };
}

/// Default sort: an explicit fixed_order (the sunnah sequence of the
/// post-prayer adhkar) beats everything. Otherwise: Quran passages always
/// first, then the tiered dhikrs, then the high-repetition dhikrs, and full
/// surahs last of all; then benefit tier (protection, reward, none); then
/// repetition count ascending; short before long at the same count; then
/// the curated sort_hint (cluster members share one value, e.g. the
/// أصبحنا/أمسينا dhikrs, so they stay together ahead of their group); and as
/// the least rule, fewer words first.
int compareDhikrs(Dhikr a, Dhikr b) {
  final byFixed = a.fixedOrder.compareTo(b.fixedOrder);
  if (byFixed != 0) return byFixed;
  final byBand = _band(a).compareTo(_band(b));
  if (byBand != 0) return byBand;
  final byTier = a.tier.index.compareTo(b.tier.index);
  if (byTier != 0) return byTier;
  final byCount = a.repetitions.compareTo(b.repetitions);
  if (byCount != 0) return byCount;
  final byForm = a.form.index.compareTo(b.form.index);
  if (byForm != 0) return byForm;
  final byHint = a.sortHint.compareTo(b.sortHint);
  if (byHint != 0) return byHint;
  return a.wordCount.compareTo(b.wordCount);
}

class ContentRepository {
  final List<Dhikr> all;

  ContentRepository(this.all);

  static Future<ContentRepository> load() async {
    final raw = await rootBundle.loadString('assets/adhkar.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final dhikrs = (json['dhikrs'] as List)
        .map((d) => Dhikr.fromJson(d as Map<String, dynamic>))
        .toList();
    return ContentRepository(dhikrs);
  }

  Dhikr byId(String id) => all.firstWhere((d) => d.id == id);

  /// Dhikrs of [session] in default order.
  List<Dhikr> defaultList(SessionType session) =>
      all.where((d) => d.contexts.contains(session)).toList()
        ..sort(compareDhikrs);

  /// Dhikrs of [session] in the user's order if one is set, else default.
  /// Ids in [userOrder] that no longer exist are dropped; dhikrs missing
  /// from [userOrder] (e.g. added by a content update) are appended in
  /// default order.
  List<Dhikr> orderedList(SessionType session, List<String> userOrder) {
    final defaults = defaultList(session);
    if (userOrder.isEmpty) return defaults;
    final byId = {for (final d in defaults) d.id: d};
    final result = <Dhikr>[
      for (final id in userOrder) ?byId.remove(id),
    ];
    return result..addAll(byId.values);
  }
}
