import 'package:json_annotation/json_annotation.dart';

part 'Identifiers.g.dart';

@JsonSerializable(includeIfNull: false)
class Identifiers {
  String? type;
  String? value;

  Identifiers({this.type, this.value});

  factory Identifiers.fromJson(Map<String, dynamic> json) =>
      _$IdentifiersFromJson(json);

  Map<String, dynamic> toJson() => _$IdentifiersToJson(this);
}
