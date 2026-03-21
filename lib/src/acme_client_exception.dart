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
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeDirectoryException extends AcmeClientException {
  const AcmeDirectoryException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeNonceException extends AcmeClientException {
  const AcmeNonceException(
    super.message, {
    required this.reason,
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });

  final AcmeNonceExceptionReason reason;
}

class AcmeJwsException extends AcmeClientException {
  const AcmeJwsException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeAccountKeyDigestException extends AcmeClientException {
  const AcmeAccountKeyDigestException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeAccountException extends AcmeClientException {
  const AcmeAccountException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeOrderException extends AcmeClientException {
  const AcmeOrderException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeAuthorizationException extends AcmeClientException {
  const AcmeAuthorizationException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeDnsPersistException extends AcmeClientException {
  const AcmeDnsPersistException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeValidationException extends AcmeClientException {
  const AcmeValidationException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}

class AcmeCertificateException extends AcmeClientException {
  const AcmeCertificateException(
    super.message, {
    super.uri,
    super.statusCode,
    super.type,
    super.detail,
    super.rawBody,
    super.cause,
  });
}
