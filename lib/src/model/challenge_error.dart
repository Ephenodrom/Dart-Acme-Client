import 'package:json_annotation/json_annotation.dart';

part 'challenge_error.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class ChallengeError {
  String? type;
  String? detail;
  int? status;

  ChallengeError({this.detail, this.type, this.status});

  factory ChallengeError.fromJson(Map<String, dynamic> json) =>
      _$ChallengeErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeErrorToJson(this);
}
