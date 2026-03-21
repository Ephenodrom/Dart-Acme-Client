// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dns_dcv_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DnsDcvData _$DnsDcvDataFromJson(Map<String, dynamic> json) => DnsDcvData(
  RRecord.fromJson(json['rRecord'] as Map<String, dynamic>),
  Challenge.fromJson(json['challenge'] as Map<String, dynamic>),
)..type = $enumDecode(_$DcvTypeEnumMap, json['type']);

Map<String, dynamic> _$DnsDcvDataToJson(DnsDcvData instance) =>
    <String, dynamic>{
      'type': _$DcvTypeEnumMap[instance.type]!,
      'rRecord': instance.rRecord,
      'challenge': instance.challenge,
    };

const _$DcvTypeEnumMap = {
  DcvType.DNS: 'DNS',
  DcvType.HTTP: 'HTTP',
  DcvType.DNS_PERSIST: 'DNS_PERSIST',
};
