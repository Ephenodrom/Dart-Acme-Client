enum ChallengeType { dns, http, dnsPersist }

extension ChallengeTypeWireValue on ChallengeType {
  String get wireValue => switch (this) {
    ChallengeType.dns => 'dns-01',
    ChallengeType.http => 'http-01',
    ChallengeType.dnsPersist => 'dns-persist-01',
  };

  static ChallengeType fromWireValue(String value) => switch (value) {
    'dns-01' => ChallengeType.dns,
    'http-01' => ChallengeType.http,
    'dns-persist-01' => ChallengeType.dnsPersist,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported challenge type',
    ),
  };
}
