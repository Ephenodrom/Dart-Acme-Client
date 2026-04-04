import 'package:acme_client/src/model/dcv_data.dart';
import 'package:acme_client/src/model/dcv_type.dart';
import 'package:acme_client/src/model/dns_persist_challenge.dart';
import 'package:acme_client/src/model/identifiers.dart';
import 'package:acme_client/src/model/dns_persist_policy.dart';
import 'package:basic_utils/basic_utils.dart';
class DnsPersistChallengeData extends ChallengeData {
  final RRecord _rRecord;
  final DnsPersistChallenge challenge;
  final String issuerDomainName;
  final String accountUri;
  final DnsPersistPolicy policy;
  final DateTime? persistUntil;

  DnsPersistChallengeData(
    this._rRecord,
    this.challenge, {
    required this.issuerDomainName,
    required this.accountUri,
    this.policy = DnsPersistPolicy.wildcard,
    this.persistUntil,
  }) : super(DcvType.DNS_PERSIST);

  factory DnsPersistChallengeData.forAuthorization({
    required DomainIdentifier domainIdentifier,
    required DnsPersistChallenge challenge,
    required String issuerDomainName,
    required String accountUri,
    DnsPersistPolicy policy = DnsPersistPolicy.wildcard,
    DateTime? persistUntil,
  }) {
    return DnsPersistChallengeData(
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
  }

  String get txtRecordName => _rRecord.name;

  String get txtRecordValue => _rRecord.data;

  String toBindString() => DnsUtils.toBind(_rRecord);

  static String _buildRecordValue({
    required String issuerDomainName,
    required String accountUri,
    DnsPersistPolicy policy = DnsPersistPolicy.wildcard,
    DateTime? persistUntil,
  }) {
    final parts = <String>[issuerDomainName, 'accounturi=$accountUri'];

    parts.add('policy=${policy.wireValue}');
    if (persistUntil != null) {
      parts.add(
        'persistUntil=${persistUntil.toUtc().millisecondsSinceEpoch ~/ 1000}',
      );
    }

    return parts.join('; ');
  }
}
