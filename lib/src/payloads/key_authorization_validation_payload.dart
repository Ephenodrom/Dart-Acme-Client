import 'dart:convert';

import 'package:acme_client/src/payloads/validation_payload.dart';

class KeyAuthorizationValidationPayload extends ValidationPayload {
  const KeyAuthorizationValidationPayload(this.keyAuthorization);

  final String keyAuthorization;

  @override
  String get stringContent =>
      json.encode({'keyAuthorization': keyAuthorization});
}
