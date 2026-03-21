import 'package:acme_client/src/model/challenge_error.dart';
import 'package:json_annotation/json_annotation.dart';

part 'challenge.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class Challenge {
  String? type;
  String? url;
  String? status;
  String? token;
  @JsonKey(name: 'issuer-domain-names')
  List<String>? issuerDomainNames;
  String? authorizationUrl;
  ChallengeError? error;

  Challenge({
    this.token,
    this.type,
    this.url,
    this.status,
    this.issuerDomainNames,
    this.authorizationUrl,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}
