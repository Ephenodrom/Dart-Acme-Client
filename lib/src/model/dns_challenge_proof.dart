import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:meta/meta.dart';

import 'dns_challenge.dart';
import 'identifiers.dart';
import 'key_authorization.dart';

/// The DNS TXT proof a caller must publish to satisfy a `dns-01` challenge.
///
/// This is not the CA challenge object. It is the derived proof artifact built
/// from a [DnsChallenge] plus the local identifier and account key material.
class DnsChallengeProof {
  final RRecord _rRecord;
  final DnsChallenge challenge;

  DnsChallengeProof._(this._rRecord, this.challenge);

  @internal
  factory DnsChallengeProof.forAuthorization({
    required DomainIdentifier domainIdentifier,
    required KeyAuthorization keyAuthorization,
    required DnsChallenge challenge,
  }) {
    final hash = CryptoUtils.getHashPlain(
      Uint8List.fromList(keyAuthorization.value.codeUnits),
    );
    final value = base64UrlEncode(hash).replaceAll('=', '');

    return DnsChallengeProof._(
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

  /// Formats the proof as a BIND-compatible TXT record line.
  String toBindString() => DnsUtils.toBind(_rRecord);
}
