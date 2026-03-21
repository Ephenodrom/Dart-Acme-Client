import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/dcv_data.dart';
import 'package:acme_client/src/model/dcv_type.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dns_persist_dcv_data.g.dart';

@JsonSerializable(includeIfNull: false)
class DnsPersistDcvData extends DcvData {
  RRecord rRecord;
  Challenge challenge;
  String issuerDomainName;
  String accountUri;
  String? policy;
  DateTime? persistUntil;

  DnsPersistDcvData(
    this.rRecord,
    this.challenge, {
    required this.issuerDomainName,
    required this.accountUri,
    this.policy,
    this.persistUntil,
  }) : super(DcvType.DNS_PERSIST);

  /// @Throwing(ArgumentError, reason: 'the JSON payload does not match the expected persistent DNS DCV data shape')
  factory DnsPersistDcvData.fromJson(Map<String, dynamic> json) =>
      _$DnsPersistDcvDataFromJson(json);

  Map<String, dynamic> toJson() => _$DnsPersistDcvDataToJson(this);

  String toBindString() => DnsUtils.toBind(rRecord);
}
