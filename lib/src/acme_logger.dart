enum AcmeLogLevel { debug, warning, error }

typedef AcmeLogFn = void Function(
  AcmeLogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});
