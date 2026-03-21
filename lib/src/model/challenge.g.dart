// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Challenge _$ChallengeFromJson(Map<String, dynamic> json) =>
    Challenge(
        token: json['token'] as String?,
        type: json['type'] as String?,
        url: json['url'] as String?,
        status: json['status'] as String?,
        issuerDomainNames: (json['issuer-domain-names'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        authorizationUrl: json['authorizationUrl'] as String?,
      )
      ..error = json['error'] == null
          ? null
          : ChallengeError.fromJson(json['error'] as Map<String, dynamic>);

Map<String, dynamic> _$ChallengeToJson(Challenge instance) => <String, dynamic>{
  'type': ?instance.type,
  'url': ?instance.url,
  'status': ?instance.status,
  'token': ?instance.token,
  'issuer-domain-names': ?instance.issuerDomainNames,
  'authorizationUrl': ?instance.authorizationUrl,
  'error': ?instance.error?.toJson(),
};
