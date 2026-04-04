enum DnsPersistPolicy { wildcard }

extension DnsPersistPolicyWireValue on DnsPersistPolicy {
  String get wireValue => switch (this) {
    DnsPersistPolicy.wildcard => 'wildcard',
  };

  static DnsPersistPolicy fromWireValue(String value) => switch (value) {
    'wildcard' => DnsPersistPolicy.wildcard,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported dns-persist policy',
    ),
  };
}
