import 'dart:convert';
import 'dart:typed_data';

import 'package:acme_client/src/Constants.dart';
import 'package:acme_client/src/model/Challenge.dart';
import 'package:acme_client/src/model/DnsDcvData.dart';
import 'package:acme_client/src/model/HttpDcvData.dart';
import 'package:acme_client/src/model/Identifiers.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Authorization.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class Authorization {
  String? status;
  DateTime? expires;
  Identifiers? identifier;
  List<Challenge>? challenges;
  String? digest;

  Authorization({
    this.challenges,
    this.expires,
    this.identifier,
    this.status,
    this.digest,
  });

  factory Authorization.fromJson(Map<String, dynamic> json) =>
      _$AuthorizationFromJson(json);

  Map<String, dynamic> toJson() => _$AuthorizationToJson(this);

  DnsDcvData getDnsDcvData() {
    var keyAuthorization = getKeyAuthorizationForChallenge(VALIDATION_DNS);
    var b = CryptoUtils.getHashPlain(
        Uint8List.fromList(keyAuthorization!.codeUnits));
    var value = base64Url.encode(b).replaceAll('=', '');
    return DnsDcvData(
      RRecord(
          name: '_acme-challenge.${identifier!.value}',
          rType: DnsUtils.rRecordTypeToInt(RRecordType.TXT),
          ttl: 300,
          data: value),
      getChallengeByType(VALIDATION_DNS),
    );
  }

  HttpDcvData getHttpDcvData() {
    var keyAuthorization = getKeyAuthorizationForChallenge(VALIDATION_HTTP);
    var token = keyAuthorization!.split('.').elementAt(0);
    return HttpDcvData(
      '${identifier!.value}/.well-known/acme-challenge/$token',
      keyAuthorization,
      getChallengeByType(VALIDATION_HTTP),
    );
  }

  Challenge getChallengeByType(String type) {
    return challenges!.firstWhere((element) => element.type == type);
  }

  String? getKeyAuthorizationForChallenge(String type) {
    try {
      var chall = challenges!.firstWhere((element) => element.type == type);
      var keyAuthorization = chall.token! + '.' + digest!;
      return keyAuthorization;
    } on StateError {
      return null;
    }
  }
}
