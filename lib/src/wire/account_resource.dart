// ignore_for_file: unnecessary_library_name

/// @nodoc
library account_resource;

import 'package:acme_client/src/model/account.dart';
import 'package:dio/dio.dart';

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

  factory AccountResource._fromMap(Map<String, dynamic> json) {
    return AccountResource(
      contact: (json['contact'] as List?)?.cast<String>(),
      createdAt: _parseAccountDateTime(json['createdAt']),
      initialIp: json['initialIp'] as String?,
      status: json['status'] as String?,
      termsOfServiceAgreed: json['termsOfServiceAgreed'] as bool?,
      orders: json['orders'] as String?,
    );
  }

  Account _toDomain() {
    return Account(
      contact: contact,
      createdAt: createdAt,
      initialIp: initialIp,
      status: status,
      termsOfServiceAgreed: termsOfServiceAgreed,
      orders: orders,
    );
  }
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
Account acmeAccountFromResource(AccountResource resource) => resource._toDomain();

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
Account acmeAccountFromResponse(Response response) {
  final account = acmeAccountFromResponseMap(response.data as Map<String, dynamic>);
  account.accountURL = response.headers.map['Location']?.first ?? '';
  return account;
}
