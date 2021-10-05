import 'package:json_annotation/json_annotation.dart';

part 'AcmeDirectories.g.dart';

@JsonSerializable()
class AcmeDirectories {
  String? keyChange;
  String? newAccount;
  String? newNonce;
  String? newOrder;
  String? revokeCert;

  AcmeDirectories(
      {this.keyChange,
      this.newAccount,
      this.newNonce,
      this.newOrder,
      this.revokeCert});

  factory AcmeDirectories.fromJson(Map<String, dynamic> json) =>
      _$AcmeDirectoriesFromJson(json);

  Map<String, dynamic> toJson() => _$AcmeDirectoriesToJson(this);
}
