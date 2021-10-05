import 'package:acme_client/src/model/ChallengeError.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Challenge.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class Challenge {
  String? type;
  String? url;
  String? token;
  String? authorizationUrl;
  ChallengeError? error;

  Challenge({this.token, this.type, this.url, this.authorizationUrl});

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}
