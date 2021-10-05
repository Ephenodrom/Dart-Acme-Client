// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Identifiers.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Identifiers _$IdentifiersFromJson(Map<String, dynamic> json) => Identifiers(
      type: json['type'] as String?,
      value: json['value'] as String?,
    );

Map<String, dynamic> _$IdentifiersToJson(Identifiers instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', instance.type);
  writeNotNull('value', instance.value);
  return val;
}
