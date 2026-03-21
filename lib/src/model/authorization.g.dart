// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authorization.dart';

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

Map<String, dynamic> _$AuthorizationToJson(Authorization instance) =>
    <String, dynamic>{
      'status': ?instance.status,
      'expires': ?instance.expires?.toIso8601String(),
      'identifier': ?instance.identifier?.toJson(),
      'challenges': ?instance.challenges?.map((e) => e.toJson()).toList(),
      'digest': ?instance.digest,
    };
