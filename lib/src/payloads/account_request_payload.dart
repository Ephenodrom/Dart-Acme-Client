import 'dart:convert';

import 'package:acme_client/src/payloads/jws_payload.dart';

class AccountRequestPayload implements JwsPayload {
  AccountRequestPayload({
    required bool onlyReturnExisting,
    required bool termsOfServiceAgreed,
    required List<String> contact,
  })  : _onlyReturnExisting = onlyReturnExisting,
        _termsOfServiceAgreed = termsOfServiceAgreed,
        _contact = contact;

  final bool _onlyReturnExisting;
  final bool _termsOfServiceAgreed;
  final List<String> _contact;

  @override
  String get stringContent => json.encode({
        'onlyReturnExisting': _onlyReturnExisting,
        'termsOfServiceAgreed': _termsOfServiceAgreed,
        'contact': _contact,
      });
}
