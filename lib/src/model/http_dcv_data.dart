import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/dcv_data.dart';
import 'package:acme_client/src/model/dcv_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'http_dcv_data.g.dart';

@JsonSerializable(includeIfNull: false)
class HttpDcvData extends DcvData {
  String fileName;
  String fileContent;
  Challenge challenge;

  HttpDcvData(this.fileName, this.fileContent, this.challenge)
      : super(DcvType.HTTP);

  factory HttpDcvData.fromJson(Map<String, dynamic> json) =>
      _$HttpDcvDataFromJson(json);

  Map<String, dynamic> toJson() => _$HttpDcvDataToJson(this);
}
