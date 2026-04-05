// Wire adapters intentionally use a library directive for clearer generated docs.
// The adapter docs are short enough, but the directive comment itself is long.
// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: unnecessary_library_name

/// @nodoc
library acme_directories_resource;

import 'package:dio/dio.dart';

import '../acme_client_exception.dart';
import '../acme_exception_factory.dart';
import '../model/acme_directories.dart';

class AcmeDirectoriesResource {
  AcmeDirectoriesResource({
    this.keyChange,
    this.newAccount,
    this.newNonce,
    this.newOrder,
    this.revokeCert,
  });

  final String? keyChange;
  final String? newAccount;
  final String? newNonce;
  final String? newOrder;
  final String? revokeCert;

  factory AcmeDirectoriesResource._fromMap(Map<String, dynamic> json) =>
      AcmeDirectoriesResource(
        keyChange: json['keyChange'] as String?,
        newAccount: json['newAccount'] as String?,
        newNonce: json['newNonce'] as String?,
        newOrder: json['newOrder'] as String?,
        revokeCert: json['revokeCert'] as String?,
      );

  AcmeDirectories _toDomain() => AcmeDirectories(
    keyChange: keyChange,
    newAccount: newAccount,
    newNonce: newNonce,
    newOrder: newOrder,
    revokeCert: revokeCert,
  );
}

/// Parses a wire-format ACME directory resource.
///
/// Why this exists: ACME directory decoding belongs in the internal wire layer
/// instead of on the public `AcmeDirectories` model.
AcmeDirectoriesResource acmeDirectoriesResourceFromMap(
  Map<String, dynamic> json,
) => AcmeDirectoriesResource._fromMap(json);

/// Maps a parsed directory resource to the public domain model.
///
/// Why this exists: the public directory model should remain a simple value
/// type while the wire layer owns ACME response parsing.
AcmeDirectories acmeDirectoriesFromResource(AcmeDirectoriesResource resource) =>
    resource._toDomain();

/// Maps an ACME directory response body to the public domain model.
///
/// Why this exists: connection bootstrap code needs a shared adapter without
/// keeping response parsing logic on `AcmeDirectories`.
AcmeDirectories acmeDirectoriesFromResponseMap(Map<String, dynamic> json) =>
    acmeDirectoriesFromResource(acmeDirectoriesResourceFromMap(json));

/// Fetches and maps the ACME directory document.
///
/// Why this exists: directory bootstrap is protocol-level work and the wire
/// layer should own the HTTP-to-domain conversion.
Future<AcmeDirectories> acmeDirectoriesFetch(
  Dio dio,
  String baseUrl, {
  void Function(
    AcmeDirectoryException wrapped,
    DioException exception,
    StackTrace stackTrace,
  )?
  onWrapped,
}) async {
  try {
    final response = await dio.get<Map<String, Object?>>(
      _directoryUrl(baseUrl),
    );
    return acmeDirectoriesFromResponseMap(
      response.data! as Map<String, dynamic>,
    );
  } on DioException catch (e, s) {
    throw acmeWrapDioException<AcmeDirectoryException>(
      e,
      'Failed to fetch ACME directory',
      acmeDirectoryExceptionFromDioException,
      onWrapped: (wrapped) => onWrapped?.call(wrapped, e, s),
    );
  }
}

String _directoryUrl(String baseUrl) {
  final uri = Uri.parse(baseUrl);
  if (uri.pathSegments.isNotEmpty) {
    final lastSegment = uri.pathSegments.last;
    if (lastSegment == 'dir' || lastSegment == 'directory') {
      return baseUrl;
    }
  }
  return '$baseUrl/directory';
}
