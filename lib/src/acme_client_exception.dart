enum AcmeNonceExceptionReason {
  fetchFailed,
  missingReplayNonce,
  multipleReplayNonceValues,
}

class AcmeClientException implements Exception {
  const AcmeClientException(
    this.message, {
    this.uri,
    this.statusCode,
    this.type,
    this.detail,
    this.rawBody,
    this.cause,
  });

  final String message;
  final Uri? uri;
  final int? statusCode;
  final String? type;
  final String? detail;
  final Object? rawBody;
  final Object? cause;

  @override
  String toString() => 'AcmeClientException: $message';
}

class AcmeConfigurationException extends AcmeClientException {
  const AcmeConfigurationException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeDirectoryException extends AcmeClientException {
  const AcmeDirectoryException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeNonceException extends AcmeClientException {
  const AcmeNonceException(
    String message, {
    required this.reason,
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );

  final AcmeNonceExceptionReason reason;
}

class AcmeJwsException extends AcmeClientException {
  const AcmeJwsException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeAccountKeyDigestException extends AcmeClientException {
  const AcmeAccountKeyDigestException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeAccountException extends AcmeClientException {
  const AcmeAccountException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeOrderException extends AcmeClientException {
  const AcmeOrderException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeAuthorizationException extends AcmeClientException {
  const AcmeAuthorizationException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeValidationException extends AcmeClientException {
  const AcmeValidationException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}

class AcmeCertificateException extends AcmeClientException {
  const AcmeCertificateException(
    String message, {
    Uri? uri,
    int? statusCode,
    String? type,
    String? detail,
    Object? rawBody,
    Object? cause,
  }) : super(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        );
}
