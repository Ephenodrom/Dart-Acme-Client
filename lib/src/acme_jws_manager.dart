import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jose/jose.dart';

import 'acme_client_exception.dart';
import 'acme_exception_factory.dart';
import 'acme_logger.dart';
import 'constants.dart';
import 'payloads/payloads.dart';

class AcmeJwsManager {
  AcmeJwsManager(
    this._dio,
    this.privateKeyPem,
    this.publicKeyPem, {
    this.logger,
  });

  final Dio _dio;
  final AcmeLogFn? logger;
  final String privateKeyPem;
  final String publicKeyPem;

  String? nonce;

  /// @Throwing(AcmeJwsException, reason: 'JSON Web Signature creation failed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained before creating the JSON Web Signature')
  Future<JsonWebSignature> createJws(
    String url, {
    String? newNonceUrl,
    String? accountUrl,
    bool useKid = false,
    Object? payload,
  }) async {
    if (nonce == null) {
      if (newNonceUrl == null || newNonceUrl.isEmpty) {
        throw const AcmeNonceException(
          'ACME newNonce URL is missing',
          reason: AcmeNonceExceptionReason.fetchFailed,
        );
      }
      nonce = await _getNonce(newNonceUrl);
    }
    try {
      final builder = JsonWebSignatureBuilder();
      final privateJwk = JsonWebKey.fromPem(privateKeyPem);
      final publicJwk = JsonWebKey.fromPem(publicKeyPem);

      if (payload == null) {
        builder.stringContent = '';
      } else if (payload is JwsPayload) {
        builder.stringContent = payload.stringContent;
      } else {
        builder.stringContent = json.encode(payload);
      }
      builder.addRecipient(privateJwk, algorithm: 'RS256');
      if (useKid) {
        builder.setProtectedHeader('kid', accountUrl);
      } else {
        builder.setProtectedHeader('jwk', publicJwk.toJson());
      }
      builder
        ..setProtectedHeader('nonce', nonce)
        ..setProtectedHeader('url', url);

      return builder.build();
    } on AcmeClientException {
      rethrow;
    } on ArgumentError catch (e, s) {
      _log(
        AcmeLogLevel.error,
        'Failed to create JSON Web Signature',
        error: e,
        stackTrace: s,
      );
      throw AcmeJwsException(
        'Failed to create JSON Web Signature',
        uri: Uri.tryParse(url),
        detail: e.message?.toString(),
        cause: e,
      );
    } on UnsupportedError catch (e, s) {
      _log(
        AcmeLogLevel.error,
        'Failed to create JSON Web Signature',
        error: e,
        stackTrace: s,
      );
      throw AcmeJwsException(
        'Failed to create JSON Web Signature',
        uri: Uri.tryParse(url),
        detail: e.message,
        cause: e,
      );
    } on StateError catch (e, s) {
      _log(
        AcmeLogLevel.error,
        'Failed to create JSON Web Signature',
        error: e,
        stackTrace: s,
      );
      throw AcmeJwsException(
        'Failed to create JSON Web Signature',
        uri: Uri.tryParse(url),
        detail: e.message,
        cause: e,
      );
    }
  }

  /// @Throwing(AcmeNonceException, reason: 'the replay nonce header could not be read from the response')
  void updateNonce(Response<Object?> response) {
    final replayNonce = _readReplayNonceHeader(
      response.headers,
      uri: response.realUri,
    );
    if (replayNonce != null && replayNonce.isNotEmpty) {
      nonce = replayNonce;
    }
  }

  /// @Throwing(AcmeNonceException, reason: 'the replay nonce header could not be read from the error response')
  void captureErrorNonce(DioException exception) {
    final replayNonce = exception.response == null
        ? null
        : _readReplayNonceHeader(
            exception.response!.headers,
            uri: exception.response!.realUri,
          );
    if (replayNonce != null && replayNonce.isNotEmpty) {
      nonce = replayNonce;
    }
  }

  /// @Throwing(AcmeNonceException, reason: 'the replay nonce request failed, returned no nonce, or returned multiple nonce values')
  Future<String> _getNonce(String newNonceUrl) async {
    try {
      final response = await _dio.head<Object?>(newNonceUrl);
      final replayNonce = _readReplayNonceHeader(
        response.headers,
        uri: Uri.tryParse(newNonceUrl),
      );
      if (replayNonce == null || replayNonce.isEmpty) {
        throw AcmeNonceException(
          'ACME server response did not include a replay nonce',
          reason: AcmeNonceExceptionReason.missingReplayNonce,
          uri: Uri.tryParse(newNonceUrl),
          rawBody: response.data,
        );
      }
      return replayNonce;
    } on DioException catch (e, s) {
      throw acmeWrapDioException(
        e,
        'Failed to fetch ACME replay nonce',
        (exception, fallbackMessage) => acmeNonceExceptionFromDioException(
          exception,
          fallbackMessage,
          reason: AcmeNonceExceptionReason.fetchFailed,
        ),
        onWrapped: (wrapped) =>
            _log(AcmeLogLevel.error, wrapped.message, error: e, stackTrace: s),
      );
    }
  }

  /// @Throwing(AcmeNonceException, reason: 'the replay nonce header contained multiple values')
  String? _readReplayNonceHeader(Headers headers, {Uri? uri}) {
    try {
      return headers.value(HEADER_REPLAY_NONCE);
    } on Exception catch (e, s) {
      _log(
        AcmeLogLevel.error,
        'ACME replay nonce header had multiple values',
        error: e,
        stackTrace: s,
      );
      throw AcmeNonceException(
        'ACME replay nonce header had multiple values',
        reason: AcmeNonceExceptionReason.multipleReplayNonceValues,
        uri: uri,
        cause: e,
      );
    }
  }

  void _log(
    AcmeLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    logger?.call(level, message, error: error, stackTrace: stackTrace);
  }
}
// Internal JOSE error mapping intentionally preserves specific low-level failures.
// ignore_for_file: avoid_catching_errors, lines_longer_than_80_chars
