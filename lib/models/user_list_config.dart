import 'dart:convert';

/// Per-context customization: explicit order and hidden (collapsed) dhikrs.
/// An empty [order] means "use the default sort".
class UserListConfig {
  final List<String> order;
  final Set<String> hidden;

  const UserListConfig({this.order = const [], this.hidden = const {}});

  bool get isDefaultOrder => order.isEmpty;

  UserListConfig copyWith({List<String>? order, Set<String>? hidden}) =>
      UserListConfig(order: order ?? this.order, hidden: hidden ?? this.hidden);

  String toJsonString() =>
      jsonEncode({'order': order, 'hidden': hidden.toList()});

  factory UserListConfig.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return UserListConfig(
      order: (json['order'] as List).cast<String>(),
      hidden: (json['hidden'] as List).cast<String>().toSet(),
    );
  }
}
