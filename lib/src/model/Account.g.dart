// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
      accountURL: json['accountURL'] as String?,
      contact:
          (json['contact'] as List<dynamic>?)?.map((e) => e as String).toList(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      initialIp: json['initialIp'] as String?,
      status: json['status'] as String?,
      termsOfServiceAgreed: json['termsOfServiceAgreed'] as bool?,
      orders: json['orders'] as String?,
    );

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
      'accountURL': instance.accountURL,
      'contact': instance.contact,
      'initialIp': instance.initialIp,
      'createdAt': instance.createdAt?.toIso8601String(),
      'status': instance.status,
      'termsOfServiceAgreed': instance.termsOfServiceAgreed,
      'orders': instance.orders,
    };
