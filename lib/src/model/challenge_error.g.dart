// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChallengeError _$ChallengeErrorFromJson(Map<String, dynamic> json) =>
    ChallengeError(
      detail: json['detail'] as String?,
      type: json['type'] as String?,
      status: (json['status'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ChallengeErrorToJson(ChallengeError instance) =>
    <String, dynamic>{
      'type': ?instance.type,
      'detail': ?instance.detail,
      'status': ?instance.status,
    };
