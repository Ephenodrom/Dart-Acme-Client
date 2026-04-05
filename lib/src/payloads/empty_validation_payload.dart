import 'dart:convert';

import 'validation_payload.dart';

class EmptyValidationPayload extends ValidationPayload {
  const EmptyValidationPayload();

  @override
  String get stringContent => json.encode(<String, dynamic>{});
}
