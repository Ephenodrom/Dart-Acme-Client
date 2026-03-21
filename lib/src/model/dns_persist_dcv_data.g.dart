// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dns_persist_dcv_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DnsPersistDcvData _$DnsPersistDcvDataFromJson(Map<String, dynamic> json) =>
    DnsPersistDcvData(
      RRecord.fromJson(json['rRecord'] as Map<String, dynamic>),
      Challenge.fromJson(json['challenge'] as Map<String, dynamic>),
      issuerDomainName: json['issuerDomainName'] as String,
      accountUri: json['accountUri'] as String,
      policy: json['policy'] as String?,
      persistUntil: json['persistUntil'] == null
          ? null
          : DateTime.parse(json['persistUntil'] as String),
    )..type = $enumDecode(_$DcvTypeEnumMap, json['type']);

Map<String, dynamic> _$DnsPersistDcvDataToJson(DnsPersistDcvData instance) =>
    <String, dynamic>{
      'type': _$DcvTypeEnumMap[instance.type]!,
      'rRecord': instance.rRecord,
      'challenge': instance.challenge,
      'issuerDomainName': instance.issuerDomainName,
      'accountUri': instance.accountUri,
      'policy': ?instance.policy,
      'persistUntil': ?instance.persistUntil?.toIso8601String(),
    };

const _$DcvTypeEnumMap = {
  DcvType.DNS: 'DNS',
  DcvType.HTTP: 'HTTP',
  DcvType.DNS_PERSIST: 'DNS_PERSIST',
};
