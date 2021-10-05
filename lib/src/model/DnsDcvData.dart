import 'package:acme_client/src/model/Challenge.dart';
import 'package:acme_client/src/model/DcvData.dart';
import 'package:acme_client/src/model/DcvType.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'DnsDcvData.g.dart';

@JsonSerializable(includeIfNull: false)
class DnsDcvData extends DcvData {
  RRecord rRecord;

  Challenge challenge;

  DnsDcvData(this.rRecord, this.challenge) : super(DcvType.DNS);

  factory DnsDcvData.fromJson(Map<String, dynamic> json) =>
      _$DnsDcvDataFromJson(json);

  Map<String, dynamic> toJson() => _$DnsDcvDataToJson(this);
}
