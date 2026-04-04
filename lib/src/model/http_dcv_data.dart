import 'package:acme_client/src/model/dcv_data.dart';
import 'package:acme_client/src/model/dcv_type.dart';
import 'package:acme_client/src/model/http_challenge.dart';
import 'package:acme_client/src/model/identifiers.dart';
class HttpChallengeData extends ChallengeData {
  final String fileName;
  final String fileContent;
  final HttpChallenge challenge;

  HttpChallengeData(this.fileName, this.fileContent, this.challenge)
    : super(DcvType.HTTP);

  factory HttpChallengeData.forAuthorization({
    required DomainIdentifier domainIdentifier,
    required String keyAuthorization,
    required HttpChallenge challenge,
  }) {
    final token = keyAuthorization.split('.').first;
    return HttpChallengeData(
      '${domainIdentifier.value}/.well-known/acme-challenge/$token',
      keyAuthorization,
      challenge,
    );
  }

}
