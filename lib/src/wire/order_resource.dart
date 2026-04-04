// ignore_for_file: unnecessary_library_name

/// @nodoc
library order_resource;

import 'package:acme_client/src/model/identifiers.dart';
import 'package:acme_client/src/model/order.dart';
import 'package:acme_client/src/wire/identifier_resource.dart';
import 'package:dio/dio.dart';

class OrderResource {
  OrderResource({
    this.status,
    this.expires,
    this.notAfter,
    this.notBefore,
    this.authorizations,
    this.finalizeUrl,
    this.certificate,
    this.identifiers,
  });

  final String? status;
  final DateTime? expires;
  final DateTime? notAfter;
  final DateTime? notBefore;
  final List<String>? authorizations;
  final String? finalizeUrl;
  final String? certificate;
  final List<Identifier>? identifiers;

  factory OrderResource._fromMap(Map<String, dynamic> json) {
    return OrderResource(
      status: json['status'] as String?,
      authorizations: (json['authorizations'] as List?)?.cast<String>(),
      certificate: json['certificate'] as String?,
      expires: _parseOrderDateTime(json['expires']),
      finalizeUrl: json['finalize'] as String?,
      identifiers: acmeIdentifierListFromResources(
        acmeIdentifierResourceListFromValue(json['identifiers']),
      ),
      notAfter: _parseOrderDateTime(json['notAfter']),
      notBefore: _parseOrderDateTime(json['notBefore']),
    );
  }

  Order _toDomain() {
    return Order(
      status: status,
      authorizations: authorizations,
      certificate: certificate,
      expires: expires,
      finalizeUrl: finalizeUrl,
      identifiers: identifiers,
      notAfter: notAfter,
      notBefore: notBefore,
    );
  }
}

DateTime? _parseOrderDateTime(Object? value) => switch (value) {
  final String text when text.isNotEmpty => DateTime.tryParse(text),
  _ => null,
};

/// Parses a wire-format ACME order resource.
///
/// Why this exists: ACME order response decoding belongs in the internal wire
/// layer instead of on the public `Order` model.
OrderResource acmeOrderResourceFromMap(Map<String, dynamic> json) =>
    OrderResource._fromMap(json);

/// Maps a parsed order resource to the public domain model.
///
/// Why this exists: public `Order` instances should stay focused on fluent
/// behavior while the wire layer owns response structure.
Order acmeOrderFromResource(OrderResource resource) => resource._toDomain();

/// Maps an ACME order response body to the public domain model.
///
/// Why this exists: callers often have raw response maps and need one package-
/// internal adapter without moving parsing onto `Order`.
Order acmeOrderFromResponseMap(Map<String, dynamic> json) =>
    acmeOrderFromResource(acmeOrderResourceFromMap(json));

/// Maps an ACME order HTTP response to the public domain model.
///
/// Why this exists: the response layer still needs a direct response adapter,
/// but that adapter should live in the internal wire layer.
Order acmeOrderFromResponse(Response response) {
  final order = acmeOrderFromResponseMap(response.data as Map<String, dynamic>);
  order.orderUrl = response.headers.map['Location']?.first ?? order.orderUrl;
  return order;
}
