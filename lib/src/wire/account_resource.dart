// Wire adapters intentionally use a library directive for clearer generated docs.
// The adapter docs are short enough, but the directive comment itself is long.
// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: unnecessary_library_name

/// @nodoc
library account_resource;

import 'package:dio/dio.dart';

import '../model/account.dart';
import '../model/account_status.dart';
import '../model/order_url.dart';

class AccountResource {
  AccountResource({
    this.contact,
    this.createdAt,
    this.initialIp,
    this.status,
    this.termsOfServiceAgreed,
    this.orders,
  });

  final List<String>? contact;
  final DateTime? createdAt;
  final String? initialIp;
  final String? status;
  final bool? termsOfServiceAgreed;
  final String? orders;

  factory AccountResource._fromMap(Map<String, dynamic> json) =>
      AccountResource(
        contact: (json['contact'] as List?)?.cast<String>(),
        createdAt: _parseAccountDateTime(json['createdAt']),
        initialIp: json['initialIp'] as String?,
        status: json['status'] as String?,
        termsOfServiceAgreed: json['termsOfServiceAgreed'] as bool?,
        orders: json['orders'] as String?,
      );

  Account _toDomain() => Account(
    contact: contact ?? const [],
    createdAt: createdAt,
    status: AccountStatusWireValue.fromWireValue(status),
    termsOfServiceAgreed: termsOfServiceAgreed ?? false,
    ordersUrl: orders == null ? null : OrderUrl.parse(orders!),
  );
}

DateTime? _parseAccountDateTime(Object? value) => switch (value) {
  final String text when text.isNotEmpty => DateTime.tryParse(text),
  _ => null,
};

/// Parses a wire-format ACME account resource.
///
/// Why this exists: ACME account decoding belongs in the internal wire layer
/// instead of on the public `Account` model.
AccountResource acmeAccountResourceFromMap(Map<String, dynamic> json) =>
    AccountResource._fromMap(json);

/// Maps a parsed account resource to the public domain model.
///
/// Why this exists: the public `Account` type should only expose fluent API
/// behavior while wire parsing remains internal.
Account acmeAccountFromResource(AccountResource resource) =>
    resource._toDomain();

/// Maps an ACME account response body to the public domain model.
///
/// Why this exists: callers often have raw response maps and need a shared
/// package-internal adapter without parsing on `Account`.
Account acmeAccountFromResponseMap(Map<String, dynamic> json) =>
    acmeAccountFromResource(acmeAccountResourceFromMap(json));

/// Maps an ACME account HTTP response to the public domain model.
///
/// Why this exists: the response layer still needs a direct response adapter,
/// but that adapter should live in the internal wire layer.
Account acmeAccountFromResponse(Response<Object?> response) {
  final resource = acmeAccountResourceFromMap(
    response.data! as Map<String, dynamic>,
  );
  return Account(
    accountURL: response.headers.map['Location']?.first ?? '',
    contact: resource.contact ?? const [],
    createdAt: resource.createdAt,
    status: AccountStatusWireValue.fromWireValue(resource.status),
    termsOfServiceAgreed: resource.termsOfServiceAgreed ?? false,
    ordersUrl: resource.orders == null
        ? null
        : OrderUrl.parse(resource.orders!),
  );
}
