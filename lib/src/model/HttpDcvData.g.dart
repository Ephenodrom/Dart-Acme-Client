// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HttpDcvData.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HttpDcvData _$HttpDcvDataFromJson(Map<String, dynamic> json) => HttpDcvData(
      json['fileName'] as String,
      json['fileContent'] as String,
      Challenge.fromJson(json['challenge'] as Map<String, dynamic>),
    )..type = _$enumDecode(_$DcvTypeEnumMap, json['type']);

Map<String, dynamic> _$HttpDcvDataToJson(HttpDcvData instance) =>
    <String, dynamic>{
      'type': _$DcvTypeEnumMap[instance.type],
      'fileName': instance.fileName,
      'fileContent': instance.fileContent,
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
