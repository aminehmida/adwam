import 'dart:convert';

/// Per-context customization: explicit order and hidden (collapsed) dhikrs.
/// An empty [order] means "use the default sort".
class UserListConfig {
  final List<String> order;
  final Set<String> hidden;

  /// Whether drag-reorder may cross section boundaries. Mixing tiers makes
  /// the section bands meaningless — one would head nearly every card — so a
  /// free-ordered session is drawn without them.
  final bool freeOrder;

  const UserListConfig({
    this.order = const [],
    this.hidden = const {},
    this.freeOrder = false,
  });

  bool get isDefaultOrder => order.isEmpty;

  UserListConfig copyWith({
    List<String>? order,
    Set<String>? hidden,
    bool? freeOrder,
  }) =>
      UserListConfig(
        order: order ?? this.order,
        hidden: hidden ?? this.hidden,
        freeOrder: freeOrder ?? this.freeOrder,
      );

  String toJsonString() => jsonEncode({
        'order': order,
        'hidden': hidden.toList(),
        if (freeOrder) 'freeOrder': true,
      });

  factory UserListConfig.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return UserListConfig(
      order: (json['order'] as List).cast<String>(),
      hidden: (json['hidden'] as List).cast<String>().toSet(),
      freeOrder: json['freeOrder'] as bool? ?? false,
    );
  }
}
