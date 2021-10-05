// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      status: json['status'] as String?,
      authorizations: (json['authorizations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      certificate: json['certificate'] as String?,
      expires: json['expires'] == null
          ? null
          : DateTime.parse(json['expires'] as String),
      finalize: json['finalize'] as String?,
      identifiers: (json['identifiers'] as List<dynamic>?)
          ?.map((e) => Identifiers.fromJson(e as Map<String, dynamic>))
          .toList(),
      notAfter: json['notAfter'] == null
          ? null
          : DateTime.parse(json['notAfter'] as String),
      notBefore: json['notBefore'] == null
          ? null
          : DateTime.parse(json['notBefore'] as String),
      orderUrl: json['orderUrl'] as String?,
    );

Map<String, dynamic> _$OrderToJson(Order instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('status', instance.status);
  writeNotNull('expires', instance.expires?.toIso8601String());
  writeNotNull('notAfter', instance.notAfter?.toIso8601String());
  writeNotNull('notBefore', instance.notBefore?.toIso8601String());
  writeNotNull('authorizations', instance.authorizations);
  writeNotNull('finalize', instance.finalize);
  writeNotNull('certificate', instance.certificate);
  writeNotNull(
      'identifiers', instance.identifiers?.map((e) => e.toJson()).toList());
  writeNotNull('orderUrl', instance.orderUrl);
  return val;
}
