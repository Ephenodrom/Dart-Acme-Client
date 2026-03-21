// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

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

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'status': ?instance.status,
  'expires': ?instance.expires?.toIso8601String(),
  'notAfter': ?instance.notAfter?.toIso8601String(),
  'notBefore': ?instance.notBefore?.toIso8601String(),
  'authorizations': ?instance.authorizations,
  'finalize': ?instance.finalize,
  'certificate': ?instance.certificate,
  'identifiers': ?instance.identifiers?.map((e) => e.toJson()).toList(),
  'orderUrl': ?instance.orderUrl,
};
