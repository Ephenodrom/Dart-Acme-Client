import 'package:basic_utils/basic_utils.dart';
import 'package:meta/meta.dart';

import 'dns_persist_challenge.dart';
import 'dns_persist_policy.dart';
import 'identifiers.dart';

/// The persistent DNS TXT proof a caller must publish to satisfy a
/// `dns-persist-01` challenge.
///
/// Call txtRecordName and txtRecordValue to get the record name and value to
/// publish to your DNS server.
class DnsPersistChallengeProof {
  final DnsPersistChallenge challenge;
  final String issuerDomainName;
  final String accountUri;
  final DnsPersistPolicy policy;
  final DateTime? persistUntil;

  final RRecord _rRecord;

  DnsPersistChallengeProof._(
    this._rRecord,
    this.challenge, {
    required this.issuerDomainName,
    required this.accountUri,
    this.policy = DnsPersistPolicy.fqdn,
    this.persistUntil,
  });

  @internal
  factory DnsPersistChallengeProof.forAuthorization({
    required DomainIdentifier domainIdentifier,
    required DnsPersistChallenge challenge,
    required String issuerDomainName,
    required String accountUri,
    DnsPersistPolicy policy = DnsPersistPolicy.fqdn,
    DateTime? persistUntil,
  }) => DnsPersistChallengeProof._(
      RRecord(
        name: '_validation-persist.${domainIdentifier.value}',
        rType: DnsUtils.rRecordTypeToInt(RRecordType.TXT),
        ttl: 300,
        data: _buildRecordValue(
          issuerDomainName: issuerDomainName,
          accountUri: accountUri,
          policy: policy,
          persistUntil: persistUntil,
        ),
      ),
      challenge,
      issuerDomainName: issuerDomainName,
      accountUri: accountUri,
      policy: policy,
      persistUntil: persistUntil,
    );

  String get txtRecordName => _rRecord.name;

  String get txtRecordValue => _rRecord.data;

  /// Formats the proof as a BIND-compatible TXT record line.
  String toBindString() => DnsUtils.toBind(_rRecord);

  static String _buildRecordValue({
    required String issuerDomainName,
    required String accountUri,
    DnsPersistPolicy policy = DnsPersistPolicy.fqdn,
    DateTime? persistUntil,
  }) {
    final parts = <String>[issuerDomainName, 'accounturi=$accountUri'];

    final wirePolicy = policy.wireValue;
    if (wirePolicy != null) {
      parts.add('policy=$wirePolicy');
    }
    if (persistUntil != null) {
      parts.add(
        'persistUntil=${persistUntil.toUtc().millisecondsSinceEpoch ~/ 1000}',
      );
    }

    return parts.join('; ');
  }
}
