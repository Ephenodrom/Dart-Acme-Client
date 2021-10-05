import 'package:json_annotation/json_annotation.dart';

part 'Account.g.dart';

@JsonSerializable()
class Account {
  String? accountURL;
  List<String>? contact;
  String? initialIp;
  DateTime? createdAt;
  String? status;
  bool? termsOfServiceAgreed;
  String? orders;

  Account(
      {this.accountURL,
      this.contact,
      this.createdAt,
      this.initialIp,
      this.status,
      this.termsOfServiceAgreed,
      this.orders});

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);
}
