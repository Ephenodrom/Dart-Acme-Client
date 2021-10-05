// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Challenge _$ChallengeFromJson(Map<String, dynamic> json) => Challenge(
      token: json['token'] as String?,
      type: json['type'] as String?,
      url: json['url'] as String?,
      authorizationUrl: json['authorizationUrl'] as String?,
    )..error = json['error'] == null
        ? null
        : ChallengeError.fromJson(json['error'] as Map<String, dynamic>);

Map<String, dynamic> _$ChallengeToJson(Challenge instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', instance.type);
  writeNotNull('url', instance.url);
  writeNotNull('token', instance.token);
  writeNotNull('authorizationUrl', instance.authorizationUrl);
  writeNotNull('error', instance.error?.toJson());
  return val;
}
