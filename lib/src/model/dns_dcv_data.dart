import 'dart:convert';
import 'dart:typed_data';

import 'package:acme_client/src/model/dcv_data.dart';
import 'package:acme_client/src/model/dcv_type.dart';
import 'package:acme_client/src/model/dns_challenge.dart';
import 'package:acme_client/src/model/identifiers.dart';
import 'package:basic_utils/basic_utils.dart';
class DnsChallengeData extends ChallengeData {
  final RRecord _rRecord;
  final DnsChallenge challenge;

  DnsChallengeData._(this._rRecord, this.challenge) : super(DcvType.DNS);

  factory DnsChallengeData.forAuthorization({
    required DomainIdentifier domainIdentifier,
    required String keyAuthorization,
    required DnsChallenge challenge,
  }) {
    final hash = CryptoUtils.getHashPlain(
      Uint8List.fromList(keyAuthorization.codeUnits),
    );
    final value = base64UrlEncode(hash).replaceAll('=', '');

    return DnsChallengeData._(
      RRecord(
        name: '_acme-challenge.${domainIdentifier.value}',
        rType: DnsUtils.rRecordTypeToInt(RRecordType.TXT),
        ttl: 300,
        data: value,
      ),
      challenge,
    );
  }

  String get txtRecordName => _rRecord.name;

  String get txtRecordValue => _rRecord.data;

  String toBindString() => DnsUtils.toBind(_rRecord);
}
