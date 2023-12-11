import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/dcv_data.dart';
import 'package:acme_client/src/model/dcv_type.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dns_dcv-data.g.dart';

@JsonSerializable(includeIfNull: false)
class DnsDcvData extends DcvData {
  RRecord rRecord;

  Challenge challenge;

  DnsDcvData(this.rRecord, this.challenge) : super(DcvType.DNS);

  factory DnsDcvData.fromJson(Map<String, dynamic> json) =>
      _$DnsDcvDataFromJson(json);

  Map<String, dynamic> toJson() => _$DnsDcvDataToJson(this);
}
