// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ChallengeError.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChallengeError _$ChallengeErrorFromJson(Map<String, dynamic> json) =>
    ChallengeError(
      detail: json['detail'] as String?,
      type: json['type'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$ChallengeErrorToJson(ChallengeError instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', instance.type);
  writeNotNull('detail', instance.detail);
  writeNotNull('status', instance.status);
  return val;
}
