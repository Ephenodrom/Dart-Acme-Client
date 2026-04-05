import 'package:dio/dio.dart';

import 'acme_client_exception.dart';

T acmeWrapDioException<T extends AcmeClientException>(
  DioException exception,
  String fallbackMessage,
  T Function(DioException exception, String fallbackMessage) builder, {
  void Function(T wrapped)? onWrapped,
}) {
  final wrapped = builder(exception, fallbackMessage);
  onWrapped?.call(wrapped);
  return wrapped;
}

AcmeDirectoryException acmeDirectoryExceptionFromDioException(
  DioException exception,
  String fallbackMessage,
) => AcmeDirectoryException.fromDioException(exception, fallbackMessage);

AcmeNonceException acmeNonceExceptionFromDioException(
  DioException exception,
  String fallbackMessage, {
  required AcmeNonceExceptionReason reason,
}) => AcmeNonceException.fromDioException(
  exception,
  fallbackMessage,
  reason: reason,
);

AcmeAccountException acmeAccountExceptionFromDioException(
  DioException exception,
  String fallbackMessage,
) => AcmeAccountException.fromDioException(exception, fallbackMessage);

AcmeOrderException acmeOrderExceptionFromDioException(
  DioException exception,
  String fallbackMessage,
) => AcmeOrderException.fromDioException(exception, fallbackMessage);

AcmeAuthorizationException acmeAuthorizationExceptionFromDioException(
  DioException exception,
  String fallbackMessage,
) => AcmeAuthorizationException.fromDioException(exception, fallbackMessage);

AcmeValidationException acmeValidationExceptionFromDioException(
  DioException exception,
  String fallbackMessage,
) => AcmeValidationException.fromDioException(exception, fallbackMessage);

AcmeValidationException acmeValidationExceptionFromChallengeFailure(
  Object? failure, {
  Uri? uri,
  Object? rawBody,
  String fallbackMessage = 'ACME challenge validation failed',
}) => AcmeValidationException.fromChallengeFailure(
  failure,
  uri: uri,
  rawBody: rawBody,
  fallbackMessage: fallbackMessage,
);

AcmeCertificateException acmeCertificateExceptionFromDioException(
  DioException exception,
  String fallbackMessage,
) => AcmeCertificateException.fromDioException(exception, fallbackMessage);
