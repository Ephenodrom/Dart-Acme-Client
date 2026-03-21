import 'dart:convert';

import 'package:acme_client/src/payloads/validation_payload.dart';

class EmptyValidationPayload extends ValidationPayload {
  const EmptyValidationPayload();

  @override
  String get stringContent => json.encode(<String, dynamic>{});
}
