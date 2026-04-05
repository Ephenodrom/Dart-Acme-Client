enum DnsPersistPolicy { fqdn, wildcard }

extension DnsPersistPolicyWireValue on DnsPersistPolicy {
  String? get wireValue => switch (this) {
    DnsPersistPolicy.fqdn => null,
    DnsPersistPolicy.wildcard => 'wildcard',
  };

  static DnsPersistPolicy fromWireValue(String value) => switch (value) {
    '' => DnsPersistPolicy.fqdn,
    'wildcard' => DnsPersistPolicy.wildcard,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported dns-persist policy',
    ),
  };
}
