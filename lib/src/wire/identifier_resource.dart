// ignore_for_file: unnecessary_library_name

/// @nodoc
library identifier_resource;

import 'package:acme_client/src/model/identifiers.dart';

class IdentifierResource {
  IdentifierResource({
    required this.type,
    this.value,
  });

  final IdentifierType type;
  final String? value;

  factory IdentifierResource._fromMap(Map<String, dynamic> json) {
    return IdentifierResource(
      type: IdentifierTypeWireValue.fromWireValue(json['type'] as String),
      value: json['value'] as String?,
    );
  }

  Identifier _toDomain() => switch (type) {
    IdentifierType.dns => DomainIdentifier(value),
  };
}

Map<String, dynamic> _toRequestMap(Identifier identifier) => {
  'type': identifier.type,
  if (identifier.value != null) 'value': identifier.value,
};

/// Parses a wire-format ACME identifier resource.
///
/// Why this exists: ACME identifier decoding belongs in the internal wire
/// layer instead of on the public `Identifier` model.
IdentifierResource acmeIdentifierResourceFromMap(Map<String, dynamic> json) =>
    IdentifierResource._fromMap(json);

/// Parses a list of wire-format ACME identifier resources.
///
/// Why this exists: order and authorization decoding need a shared converter
/// while the public identifier model stays focused on domain meaning.
List<IdentifierResource>? acmeIdentifierResourceListFromValue(Object? value) =>
    value is List
        ? value
              .map(
                (identifier) => acmeIdentifierResourceFromMap(
                  identifier as Map<String, dynamic>,
                ),
              )
              .toList()
        : null;

/// Maps a parsed identifier resource to the public domain model.
///
/// Why this exists: the public `Identifier` hierarchy should stay free of raw
/// ACME parsing concerns.
Identifier acmeIdentifierFromResource(IdentifierResource resource) =>
    resource._toDomain();

/// Maps parsed identifier resources to public domain models.
///
/// Why this exists: order and authorization mappers need a shared list mapper
/// without pushing wire helpers onto `Identifier`.
List<Identifier>? acmeIdentifierListFromResources(
  List<IdentifierResource>? resources,
) => resources?.map(acmeIdentifierFromResource).toList();

/// Builds the ACME request payload shape for a public identifier.
///
/// Why this exists: request payload generation still needs the wire field
/// names, but that should remain outside the public `Identifier` model API.
Map<String, dynamic> acmeIdentifierToRequestMap(Identifier identifier) =>
    _toRequestMap(identifier);

/// Builds the ACME request payload shape for public identifiers.
///
/// Why this exists: new-order request construction needs a stable list mapper
/// without exposing generic serialization on `Identifier`.
List<Map<String, dynamic>>? acmeIdentifierListToRequestValue(
  List<Identifier>? identifiers,
) => identifiers?.map(acmeIdentifierToRequestMap).toList();
