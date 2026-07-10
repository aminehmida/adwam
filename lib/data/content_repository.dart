import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dhikr.dart';

/// Default sort: form band (quran, short, long), then repetition count
/// ascending, then benefit tier (protection, reward, other benefit, none).
/// Enum declaration order encodes both rankings, so `.index` is the key.
int compareDhikrs(Dhikr a, Dhikr b) {
  final byForm = a.form.index.compareTo(b.form.index);
  if (byForm != 0) return byForm;
  final byCount = a.repetitions.compareTo(b.repetitions);
  if (byCount != 0) return byCount;
  return a.tier.index.compareTo(b.tier.index);
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
      for (final id in userOrder)
        if (byId.remove(id) case final d?) d,
    ];
    return result..addAll(byId.values);
  }
}
