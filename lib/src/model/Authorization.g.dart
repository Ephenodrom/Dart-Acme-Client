// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Authorization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Authorization _$AuthorizationFromJson(Map<String, dynamic> json) =>
    Authorization(
      challenges: (json['challenges'] as List<dynamic>?)
          ?.map((e) => Challenge.fromJson(e as Map<String, dynamic>))
          .toList(),
      expires: json['expires'] == null
          ? null
          : DateTime.parse(json['expires'] as String),
      identifier: json['identifier'] == null
          ? null
          : Identifiers.fromJson(json['identifier'] as Map<String, dynamic>),
      status: json['status'] as String?,
      digest: json['digest'] as String?,
    );

Map<String, dynamic> _$AuthorizationToJson(Authorization instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('status', instance.status);
  writeNotNull('expires', instance.expires?.toIso8601String());
  writeNotNull('identifier', instance.identifier?.toJson());
  writeNotNull(
      'challenges', instance.challenges?.map((e) => e.toJson()).toList());
  writeNotNull('digest', instance.digest);
  return val;
}
