enum AccountStatus { unknown, valid, deactivated, revoked }

extension AccountStatusWireValue on AccountStatus {
  String get wireValue => switch (this) {
    AccountStatus.unknown => '',
    AccountStatus.valid => 'valid',
    AccountStatus.deactivated => 'deactivated',
    AccountStatus.revoked => 'revoked',
  };

  static AccountStatus fromWireValue(String? value) => switch (value) {
    'valid' => AccountStatus.valid,
    'deactivated' => AccountStatus.deactivated,
    'revoked' => AccountStatus.revoked,
    _ => AccountStatus.unknown,
  };
}
