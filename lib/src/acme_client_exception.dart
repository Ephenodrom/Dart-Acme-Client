import 'package:dio/dio.dart';

enum AcmeNonceExceptionReason {
  fetchFailed,
  missingReplayNonce,
  multipleReplayNonceValues,
}

class _AcmeErrorFields {
  const _AcmeErrorFields({
    required this.message,
    this.uri,
    this.statusCode,
    this.type,
    this.detail,
    this.rawBody,
    this.cause,
  });

  factory _AcmeErrorFields.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final response = exception.response;
    final rawBody = response?.data;
    final detail = _extractErrorDetail(rawBody) ?? exception.message;
    final message = detail == null || detail.isEmpty
        ? fallbackMessage
        : '$fallbackMessage: $detail';

    return _AcmeErrorFields(
      message: message,
      uri: Uri.tryParse(
        response?.realUri.toString() ?? exception.requestOptions.uri.toString(),
      ),
      statusCode: response?.statusCode,
      type: _extractErrorType(rawBody),
      detail: detail,
      rawBody: rawBody,
      cause: exception,
    );
  }

  factory _AcmeErrorFields.fromChallengeFailure(
    Object? failure, {
    required String fallbackMessage,
    Uri? uri,
    Object? rawBody,
  }) {
    final detail = _extractChallengeFailureDetail(failure);
    final message = detail == null || detail.isEmpty
        ? fallbackMessage
        : '$fallbackMessage: $detail';

    return _AcmeErrorFields(
      message: message,
      uri: uri,
      statusCode: _extractChallengeFailureStatus(failure),
      type: _extractChallengeFailureType(failure),
      detail: detail,
      rawBody: rawBody,
    );
  }

  final String message;
  final Uri? uri;
  final int? statusCode;
  final String? type;
  final String? detail;
  final Object? rawBody;
  final Object? cause;

  static String? _extractErrorDetail(Object? rawBody) {
    if (rawBody is Map<String, dynamic>) {
      final challengeDetail = _nestedString(rawBody, [
        'challenges',
        '0',
        'error',
        'detail',
      ]);
      if (challengeDetail != null && challengeDetail.isNotEmpty) {
        return challengeDetail;
      }

      final detail = rawBody['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      final error = rawBody['error'];
      if (error is Map<String, dynamic>) {
        final nestedDetail = error['detail'];
        if (nestedDetail is String && nestedDetail.isNotEmpty) {
          return nestedDetail;
        }
      }
    }

    if (rawBody is String && rawBody.isNotEmpty) {
      return rawBody;
    }

    return null;
  }

  static String? _extractErrorType(Object? rawBody) {
    if (rawBody is Map<String, dynamic>) {
      final challengeType = _nestedString(rawBody, [
        'challenges',
        '0',
        'error',
        'type',
      ]);
      if (challengeType != null && challengeType.isNotEmpty) {
        return challengeType;
      }

      final type = rawBody['type'];
      if (type is String && type.isNotEmpty) {
        return type;
      }

      final error = rawBody['error'];
      if (error is Map<String, dynamic>) {
        final nestedType = error['type'];
        if (nestedType is String && nestedType.isNotEmpty) {
          return nestedType;
        }
      }
    }

    return null;
  }

  static String? _nestedString(
    Map<String, dynamic> rawBody,
    List<String> path,
  ) {
    Object? current = rawBody;
    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }
      if (current is List<Object?>) {
        final index = int.tryParse(segment);
        if (index == null || index >= current.length) {
          return null;
        }
        current = current[index];
        continue;
      }
      return null;
    }
    return current is String ? current : null;
  }

  static int? _extractChallengeFailureStatus(Object? rawBody) {
    final value = _extractChallengeFailureMap(rawBody)?['status'];
    return value is int ? value : null;
  }

  static String? _extractChallengeFailureType(Object? rawBody) {
    final value = _extractChallengeFailureMap(rawBody)?['type'];
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? _extractChallengeFailureDetail(Object? rawBody) {
    final value = _extractChallengeFailureMap(rawBody)?['detail'];
    return value is String && value.isNotEmpty ? value : null;
  }

  static Map<String, dynamic>? _extractChallengeFailureMap(Object? rawBody) {
    if (rawBody is! Map<String, dynamic>) {
      return null;
    }
    final challenges = rawBody['challenges'];
    if (challenges is! List) {
      return null;
    }
    for (final item in challenges) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final error = item['error'];
      if (error is Map<String, dynamic>) {
        return error;
      }
    }
    return null;
  }
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

  static T wrapDioException<T extends AcmeClientException>(
    DioException exception,
    String fallbackMessage,
    T Function(DioException exception, String fallbackMessage) builder, {
    void Function(T wrapped)? onWrapped,
  }) {
    final wrapped = builder(exception, fallbackMessage);
    onWrapped?.call(wrapped);
    return wrapped;
  }

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

  factory AcmeDirectoryException.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeDirectoryException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
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

  factory AcmeNonceException.fromDioException(
    DioException exception,
    String fallbackMessage, {
    required AcmeNonceExceptionReason reason,
  }) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeNonceException(
      fields.message,
      reason: reason,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
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

  factory AcmeAccountException.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeAccountException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
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

  factory AcmeOrderException.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeOrderException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
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

  factory AcmeAuthorizationException.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeAuthorizationException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
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

  factory AcmeValidationException.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeValidationException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }

  factory AcmeValidationException.fromChallengeFailure(
    Object? failure, {
    Uri? uri,
    Object? rawBody,
    String fallbackMessage = 'ACME challenge validation failed',
  }) {
    final fields = _AcmeErrorFields.fromChallengeFailure(
      failure,
      fallbackMessage: fallbackMessage,
      uri: uri,
      rawBody: rawBody,
    );
    return AcmeValidationException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
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

  factory AcmeCertificateException.fromDioException(
    DioException exception,
    String fallbackMessage,
  ) {
    final fields = _AcmeErrorFields.fromDioException(
      exception,
      fallbackMessage,
    );
    return AcmeCertificateException(
      fields.message,
      uri: fields.uri,
      statusCode: fields.statusCode,
      type: fields.type,
      detail: fields.detail,
      rawBody: fields.rawBody,
      cause: fields.cause,
    );
  }
}
