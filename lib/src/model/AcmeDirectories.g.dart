// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AcmeDirectories.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcmeDirectories _$AcmeDirectoriesFromJson(Map<String, dynamic> json) =>
    AcmeDirectories(
      keyChange: json['keyChange'] as String?,
      newAccount: json['newAccount'] as String?,
      newNonce: json['newNonce'] as String?,
      newOrder: json['newOrder'] as String?,
      revokeCert: json['revokeCert'] as String?,
    );

Map<String, dynamic> _$AcmeDirectoriesToJson(AcmeDirectories instance) =>
    <String, dynamic>{
      'keyChange': instance.keyChange,
      'newAccount': instance.newAccount,
      'newNonce': instance.newNonce,
      'newOrder': instance.newOrder,
      'revokeCert': instance.revokeCert,
    };
