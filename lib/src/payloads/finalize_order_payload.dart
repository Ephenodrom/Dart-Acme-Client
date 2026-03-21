import 'dart:convert';

import 'package:acme_client/src/payloads/jws_payload.dart';

class FinalizeOrderPayload implements JwsPayload {
  FinalizeOrderPayload(this._csr);

  final String _csr;

  @override
  String get stringContent => json.encode({
        'csr': _csr,
      });
}
