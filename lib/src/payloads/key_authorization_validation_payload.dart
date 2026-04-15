import 'dart:convert';

import '../model/key_authorization.dart';
import 'validation_payload.dart';

class KeyAuthorizationValidationPayload extends ValidationPayload {
  const KeyAuthorizationValidationPayload(this.keyAuthorization);

  final KeyAuthorization keyAuthorization;

  @override
  String get stringContent =>
      json.encode({'keyAuthorization': keyAuthorization.value});
}
