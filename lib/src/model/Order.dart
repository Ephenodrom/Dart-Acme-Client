import 'package:acme_client/src/model/Identifiers.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Order.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class Order {
  String? status;
  DateTime? expires;
  DateTime? notAfter;
  DateTime? notBefore;
  List<String>? authorizations;
  String? finalize;
  String? certificate;
  List<Identifiers>? identifiers;
  String? orderUrl;

  Order({
    this.status,
    this.authorizations,
    this.certificate,
    this.expires,
    this.finalize,
    this.identifiers,
    this.notAfter,
    this.notBefore,
    this.orderUrl,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
