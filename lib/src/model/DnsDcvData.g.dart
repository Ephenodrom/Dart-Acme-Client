// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'DnsDcvData.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DnsDcvData _$DnsDcvDataFromJson(Map<String, dynamic> json) => DnsDcvData(
      RRecord.fromJson(json['rRecord'] as Map<String, dynamic>),
      Challenge.fromJson(json['challenge'] as Map<String, dynamic>),
    )..type = _$enumDecode(_$DcvTypeEnumMap, json['type']);

Map<String, dynamic> _$DnsDcvDataToJson(DnsDcvData instance) =>
    <String, dynamic>{
      'type': _$DcvTypeEnumMap[instance.type],
      'rRecord': instance.rRecord,
      'challenge': instance.challenge,
    };

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

const _$DcvTypeEnumMap = {
  DcvType.DNS: 'DNS',
  DcvType.HTTP: 'HTTP',
};
