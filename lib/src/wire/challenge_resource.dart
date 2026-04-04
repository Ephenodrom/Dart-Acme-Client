// ignore_for_file: unnecessary_library_name

/// @nodoc
library challenge_resource;

import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/challenge_type.dart';
import 'package:acme_client/src/model/dns_challenge.dart';
import 'package:acme_client/src/model/dns_persist_challenge.dart';
import 'package:acme_client/src/model/http_challenge.dart';

class ChallengeResource {
  ChallengeResource({
    required this.type,
    this.url,
    this.status,
    this.token,
    this.issuerDomainNames,
  });

  final ChallengeType type;
  final String? url;
  final String? status;
  final String? token;
  final List<String>? issuerDomainNames;

  factory ChallengeResource._fromMap(Map<String, dynamic> json) {
    return ChallengeResource(
      type: ChallengeTypeWireValue.fromWireValue(json['type'] as String),
      url: json['url'] as String?,
      status: json['status'] as String?,
      token: json['token'] as String?,
      issuerDomainNames: (json['issuer-domain-names'] as List<dynamic>?)
          ?.cast<String>(),
    );
  }

  Challenge _toDomain() => switch (type) {
    ChallengeType.dns => DnsChallenge(
      url: url,
      status: status,
      token: token,
    ),
    ChallengeType.http => HttpChallenge(
      url: url,
      status: status,
      token: token,
    ),
    ChallengeType.dnsPersist => DnsPersistChallenge(
      url: url,
      status: status,
      token: token,
      issuerDomainNames: issuerDomainNames,
    ),
  };
}

/// Parses a wire-format ACME challenge resource.
///
/// Why this exists: ACME response decoding belongs in the internal wire layer,
/// not on the public `Challenge` model hierarchy.
ChallengeResource acmeChallengeResourceFromMap(Map<String, dynamic> json) =>
    ChallengeResource._fromMap(json);

/// Parses a list of wire-format ACME challenge resources.
///
/// Why this exists: authorization decoding needs a shared list converter while
/// keeping public challenge models free of wire parsing helpers.
List<ChallengeResource>? acmeChallengeResourceListFromValue(Object? value) =>
    value is List
        ? value
              .map(
                (challenge) =>
                    acmeChallengeResourceFromMap(challenge as Map<String, dynamic>),
              )
              .toList()
        : null;

/// Maps a parsed challenge resource to the public domain model.
///
/// Why this exists: the public `Challenge` types should only expose behavior,
/// while the wire layer owns ACME response structure.
Challenge acmeChallengeFromResource(ChallengeResource resource) =>
    resource._toDomain();

/// Maps parsed challenge resources to public domain models.
///
/// Why this exists: authorization mapping needs a shared list mapper without
/// moving resource knowledge onto the public `Challenge` API.
List<Challenge>? acmeChallengeListFromResources(
  List<ChallengeResource>? resources,
) => resources?.map(acmeChallengeFromResource).toList();
