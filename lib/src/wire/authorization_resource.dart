// Wire adapters intentionally use a library directive for clearer generated docs.
// The adapter docs are short enough, but the directive comment itself is long.
// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: unnecessary_library_name

/// @nodoc
library authorization_resource;

import 'package:dio/dio.dart';

import '../model/authorization.dart';
import '../model/challenge.dart';
import '../model/identifiers.dart';
import 'challenge_resource.dart';
import 'identifier_resource.dart';

class AuthorizationResource {
  AuthorizationResource({
    this.status,
    this.expires,
    this.identifier,
    this.challenges,
  });

  final String? status;
  final DateTime? expires;
  final Identifier? identifier;
  final List<ChallengeResource>? challenges;

  factory AuthorizationResource._fromMap(Map<String, dynamic> json) =>
      AuthorizationResource(
        status: json['status'] as String?,
        expires: _parseResourceDateTime(json['expires']),
        identifier: json['identifier'] is Map<String, dynamic>
            ? acmeIdentifierFromResource(
                acmeIdentifierResourceFromMap(
                  json['identifier'] as Map<String, dynamic>,
                ),
              )
            : null,
        challenges: acmeChallengeResourceListFromValue(json['challenges']),
      );

  Authorization _toDomain({String? authorizationUrl}) {
    final authorization = Authorization(
      status: status,
      expires: expires,
      identifier: identifier,
      challenges: acmeChallengeListFromResources(challenges),
    );
    for (final challenge in authorization.challenges ?? const <Challenge>[]) {
      challenge.authorizationUrl = authorizationUrl;
    }
    return authorization;
  }
}

DateTime? _parseResourceDateTime(Object? value) => switch (value) {
  final String text when text.isNotEmpty => DateTime.tryParse(text),
  _ => null,
};

/// Parses a wire-format ACME authorization resource.
///
/// Why this exists: authorization response decoding belongs in the internal
/// wire layer instead of on the public `Authorization` model.
AuthorizationResource acmeAuthorizationResourceFromMap(
  Map<String, dynamic> json,
) => AuthorizationResource._fromMap(json);

/// Maps a parsed authorization resource to the public domain model.
///
/// Why this exists: fluent authorization behavior lives on the public model,
/// while ACME wire structure stays isolated in the wire layer.
Authorization acmeAuthorizationFromResource(
  AuthorizationResource resource, {
  String? authorizationUrl,
}) => resource._toDomain(authorizationUrl: authorizationUrl);

/// Maps an ACME authorization response body to the public domain model.
///
/// Why this exists: callers often have raw response maps and need a single
/// package-internal helper without pushing parsing onto `Authorization`.
Authorization acmeAuthorizationFromResponseMap(
  Map<String, dynamic> json, {
  String? authorizationUrl,
}) => acmeAuthorizationFromResource(
  acmeAuthorizationResourceFromMap(json),
  authorizationUrl: authorizationUrl,
);

/// Maps an ACME authorization HTTP response to the public domain model.
///
/// Why this exists: the response layer still needs a direct response adapter,
/// but that adapter should live in the internal wire layer.
Authorization acmeAuthorizationFromResponse(
  Response<Object?> response, {
  required String authorizationUrl,
}) => acmeAuthorizationFromResponseMap(
  response.data! as Map<String, dynamic>,
  authorizationUrl: authorizationUrl,
);
